"""Shared core dependencies (DB, auth, models) used across server.py and routers/."""
from fastapi import HTTPException, Request, Depends
from pydantic import BaseModel, ConfigDict
from typing import List, Optional, Dict, Any
from datetime import datetime, timezone, timedelta
import os
import json
import uuid
import jwt
import httpx
import asyncpg
import copy
from dotenv import load_dotenv
from pathlib import Path

ROOT_DIR = Path(__file__).parent
load_dotenv(ROOT_DIR / '.env')

FIREBASE_PROJECT_ID = os.environ.get("FIREBASE_PROJECT_ID", "final-evolution-lab")
EMERGENT_KEY = os.environ.get('GEMINI_API_KEY') or os.environ.get('EMERGENT_LLM_KEY', '')

# Database Connection Pool Setup
db_pool = None

async def init_db():
    global db_pool
    if db_pool is None:
        database_url = os.environ.get("DATABASE_URL")
        if not database_url:
            # Fallback to individual parameters or local defaults
            db_user = os.environ.get("DB_USER", "postgres")
            db_pass = os.environ.get("DB_PASS", "postgres")
            db_host = os.environ.get("DB_HOST", "localhost")
            db_port = os.environ.get("DB_PORT", "5432")
            db_name = os.environ.get("DB_NAME", "fdcdb")
            database_url = f"postgresql://{db_user}:{db_pass}@{db_host}:{db_port}/{db_name}"
        db_pool = await asyncpg.create_pool(database_url, min_size=1, max_size=20)

async def get_db_pool():
    global db_pool
    if db_pool is None:
        await init_db()
    return db_pool

async def execute(query: str, *args):
    pool = await get_db_pool()
    async with pool.acquire() as conn:
        return await conn.execute(query, *args)

async def fetch(query: str, *args):
    pool = await get_db_pool()
    async with pool.acquire() as conn:
        return await conn.fetch(query, *args)

async def fetchrow(query: str, *args):
    pool = await get_db_pool()
    async with pool.acquire() as conn:
        return await conn.fetchrow(query, *args)


# MongoDB to PostgreSQL Adapter Helpers
def match_document(doc: dict, filter: dict) -> bool:
    for key, val in filter.items():
        if key == "$or":
            if not isinstance(val, list): return False
            if not any(match_document(doc, sub) for sub in val):
                return False
            continue
        if key == "$and":
            if not isinstance(val, list): return False
            if not all(match_document(doc, sub) for sub in val):
                return False
            continue
        
        # Navigate nested path, e.g. "vitals.heartRate"
        parts = key.split('.')
        doc_val = doc
        for p in parts:
            if p == '_id' and isinstance(doc_val, dict) and '_id' not in doc_val:
                p = 'id'
            elif p == 'id' and isinstance(doc_val, dict) and 'id' not in doc_val:
                p = '_id'
            if isinstance(doc_val, dict) and p in doc_val:
                doc_val = doc_val[p]
            else:
                doc_val = None
                break
        
        if isinstance(val, dict):
            for op, op_val in val.items():
                if op == "$eq":
                    if doc_val != op_val: return False
                elif op == "$ne":
                    if doc_val == op_val: return False
                elif op == "$gt":
                    if doc_val is None or doc_val <= op_val: return False
                elif op == "$gte":
                    if doc_val is None or doc_val < op_val: return False
                elif op == "$lt":
                    if doc_val is None or doc_val >= op_val: return False
                elif op == "$lte":
                    if doc_val is None or doc_val > op_val: return False
                elif op == "$in":
                    if doc_val not in op_val: return False
                elif op == "$nin":
                    if doc_val in op_val: return False
                elif op == "$regex":
                    import re
                    flags = 0
                    if "$options" in val and "i" in val["$options"]:
                        flags = re.IGNORECASE
                    pattern = re.compile(str(op_val), flags)
                    if not isinstance(doc_val, str) or not pattern.search(doc_val):
                        return False
        else:
            if doc_val != val:
                return False
    return True

def set_nested_value(doc: dict, path: str, val):
    parts = path.split('.')
    d = doc
    for p in parts[:-1]:
        if p not in d or not isinstance(d[p], dict):
            d[p] = {}
        d = d[p]
    d[parts[-1]] = val

def get_nested_value(doc: dict, path: str):
    parts = path.split('.')
    d = doc
    for p in parts[:-1]:
        if isinstance(d, dict) and p in d:
            d = d[p]
        else:
            return None
    return d[parts[-1]] if isinstance(d, dict) and parts[-1] in d else None

def apply_update(doc: dict, update_op: dict, is_insert: bool = False) -> dict:
    doc = copy.deepcopy(doc)
    
    # 1. $setOnInsert
    if is_insert and "$setOnInsert" in update_op:
        for k, v in update_op["$setOnInsert"].items():
            set_nested_value(doc, k, v)
            
    # 2. $set
    if "$set" in update_op:
        for k, v in update_op["$set"].items():
            set_nested_value(doc, k, v)
            
    # 3. $inc
    if "$inc" in update_op:
        for k, v in update_op["$inc"].items():
            curr = get_nested_value(doc, k) or 0
            set_nested_value(doc, k, curr + v)
            
    # 4. $push
    if "$push" in update_op:
        for k, v in update_op["$push"].items():
            curr = get_nested_value(doc, k)
            if not isinstance(curr, list):
                curr = []
            if isinstance(v, dict) and "$each" in v:
                each_list = v["$each"]
                curr.extend(each_list)
                if "$slice" in v:
                    slice_val = v["$slice"]
                    if slice_val < 0:
                        curr = curr[slice_val:]
                    else:
                        curr = curr[:slice_val]
            else:
                curr.append(v)
            set_nested_value(doc, k, curr)
            
    # 5. $addToSet
    if "$addToSet" in update_op:
        for k, v in update_op["$addToSet"].items():
            curr = get_nested_value(doc, k)
            if not isinstance(curr, list):
                curr = []
            if isinstance(v, dict) and "$each" in v:
                for x in v["$each"]:
                    if x not in curr:
                        curr.append(x)
            else:
                if v not in curr:
                    curr.append(v)
            set_nested_value(doc, k, curr)
            
    # 6. $pull
    if "$pull" in update_op:
        for k, v in update_op["$pull"].items():
            curr = get_nested_value(doc, k)
            if isinstance(curr, list):
                if isinstance(v, dict):
                    curr = [item for item in curr if not match_document(item, v)]
                else:
                    curr = [item for item in curr if item != v]
                set_nested_value(doc, k, curr)
                
    return doc

def serialize_doc(doc: dict) -> dict:
    import datetime as dt_module
    doc = copy.deepcopy(doc)
    def serialize_val(val):
        if isinstance(val, (dt_module.datetime, dt_module.date)):
            return val.isoformat()
        if isinstance(val, dict):
            return {k: serialize_val(v) for k, v in val.items()}
        if isinstance(val, list):
            return [serialize_val(x) for x in val]
        return val
    return serialize_val(doc)

def parse_datetime(val: str):
    if len(val) >= 19 and val[4] == '-' and val[7] == '-' and val[10] == 'T':
        try:
            if val.endswith('Z'):
                val = val[:-1] + '+00:00'
            return datetime.fromisoformat(val)
        except Exception:
            return val
    return val

def deserialize_doc(doc: dict) -> dict:
    if not isinstance(doc, dict):
        return doc
    new_doc = {}
    for k, v in doc.items():
        if isinstance(v, str):
            new_doc[k] = parse_datetime(v)
        elif isinstance(v, dict):
            new_doc[k] = deserialize_doc(v)
        elif isinstance(v, list):
            new_doc[k] = [deserialize_doc(x) if isinstance(x, dict) else (parse_datetime(x) if isinstance(x, str) else x) for x in v]
        else:
            new_doc[k] = v
    if 'id' in new_doc and '_id' not in new_doc:
        new_doc['_id'] = new_doc['id']
    return new_doc


# Emulated MongoDB collection return results
class UpdateResult:
    def __init__(self, matched_count: int, modified_count: int, upserted_id=None):
        self.matched_count = matched_count
        self.modified_count = modified_count
        self.upserted_id = upserted_id
        self.acknowledged = True

class DeleteResult:
    def __init__(self, deleted_count: int):
        self.deleted_count = deleted_count
        self.acknowledged = True


# Cursor Wrapper Emulating MongoDB cursor chainable API
class PostgresCursor:
    def __init__(self, name: str, filter: dict, collection):
        self.name = name
        self.filter = filter
        self.collection = collection
        self._sort_field = None
        self._sort_dir = 1
        self._limit = None
        self._skip = None
        
    def sort(self, field: str, direction: int = 1):
        self._sort_field = field
        self._sort_dir = direction
        return self
        
    def limit(self, limit: int):
        self._limit = limit
        return self

    def skip(self, skip: int):
        self._skip = skip
        return self
        
    async def to_list(self, limit: Optional[int]) -> list:
        await self.collection._ensure_table()
        run_limit = limit if limit is not None else self._limit
        
        # SQL pre-filtering for simple string/int values
        sql_conds = []
        sql_args = []
        arg_idx = 1
        for k, v in self.filter.items():
            if not k.startswith('$') and '.' not in k and not isinstance(v, dict):
                if k == '_id' or k == 'id':
                    sql_conds.append(f"id = ${arg_idx}")
                    sql_args.append(str(v) if v is not None else None)
                else:
                    sql_conds.append(f"data->>'{k}' = ${arg_idx}")
                    if isinstance(v, bool):
                        sql_args.append("true" if v else "false")
                    else:
                        sql_args.append(str(v) if v is not None else None)
                arg_idx += 1
                
        where_clause = " AND ".join(sql_conds)
        query = f"SELECT data FROM public.{self.name}"
        if where_clause:
            query += f" WHERE {where_clause}"
            
        rows = await fetch(query, *sql_args)
        
        # Python matching logic for full compliance
        matched = []
        for row in rows:
            doc = deserialize_doc(json.loads(row['data']))
            if match_document(doc, self.filter):
                matched.append(doc)
                
        # Handle sorting
        if self._sort_field:
            def sort_key(doc):
                val = get_nested_value(doc, self._sort_field)
                return (val is not None, val)
            matched.sort(key=sort_key, reverse=(self._sort_dir == -1))
            
        # Handle skip
        if self._skip is not None:
            matched = matched[self._skip:]
            
        # Handle limit
        if run_limit is not None:
            matched = matched[:run_limit]
            
        return matched


# Aggregate Cursor Emulating MongoDB aggregation return value
class PostgresAggregateCursor:
    def __init__(self, collection, pipeline):
        self.collection = collection
        self.pipeline = pipeline

    async def to_list(self, limit: Optional[int]) -> list:
        await self.collection._ensure_table()
        query = f"SELECT data FROM public.{self.collection.name}"
        rows = await fetch(query)
        docs = [deserialize_doc(json.loads(row['data'])) for row in rows]
        
        for stage in self.pipeline:
            if "$match" in stage:
                match_filter = stage["$match"]
                docs = [doc for doc in docs if match_document(doc, match_filter)]
            elif "$group" in stage:
                group_spec = stage["$group"]
                group_id_spec = group_spec.get("_id")
                groups = {}
                for doc in docs:
                    if isinstance(group_id_spec, str) and group_id_spec.startswith("$"):
                        group_key = get_nested_value(doc, group_id_spec[1:])
                    else:
                        group_key = None
                    if group_key not in groups:
                        groups[group_key] = []
                    groups[group_key].append(doc)
                
                grouped_docs = []
                for g_key, g_docs in groups.items():
                    out_doc = {"_id": g_key}
                    for out_field, agg_spec in group_spec.items():
                        if out_field == "_id":
                            continue
                        if not isinstance(agg_spec, dict):
                            continue
                        op = list(agg_spec.keys())[0]
                        val_spec = agg_spec[op]
                        vals = []
                        for d in g_docs:
                            if isinstance(val_spec, (int, float)):
                                vals.append(val_spec)
                            elif isinstance(val_spec, str) and val_spec.startswith("$"):
                                v = get_nested_value(d, val_spec[1:])
                                if isinstance(v, (int, float)):
                                    vals.append(v)
                                elif v is not None:
                                    try:
                                        vals.append(float(v))
                                    except ValueError:
                                        pass
                        if op == "$sum":
                            out_doc[out_field] = sum(vals)
                        elif op == "$avg":
                            out_doc[out_field] = sum(vals) / len(vals) if vals else 0
                        elif op == "$min":
                            out_doc[out_field] = min(vals) if vals else None
                        elif op == "$max":
                            out_doc[out_field] = max(vals) if vals else None
                    grouped_docs.append(out_doc)
                docs = grouped_docs
            elif "$sort" in stage:
                sort_spec = stage["$sort"]
                for field, direction in sort_spec.items():
                    def sort_key(doc):
                        val = doc.get(field)
                        return (val is not None, val)
                    docs.sort(key=sort_key, reverse=(direction == -1))
            elif "$limit" in stage:
                limit_val = stage["$limit"]
                docs = docs[:limit_val]
                
        if limit is not None:
            return docs[:limit]
        return docs


# Collection Wrapper Emulating MongoDB CRUD operations
class PostgresCollection:
    def __init__(self, name: str, adapter):
        self.name = name
        self.adapter = adapter
        
    async def _ensure_table(self):
        if self.name not in self.adapter._initialized_tables:
            query = f"""
                CREATE TABLE IF NOT EXISTS public.{self.name} (
                    id TEXT PRIMARY KEY,
                    data JSONB NOT NULL DEFAULT '{{}}'::jsonb,
                    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
                )
            """
            await execute(query)
            # Create a index on data JSONB as well
            await execute(f"CREATE INDEX IF NOT EXISTS idx_{self.name}_data ON public.{self.name} USING gin (data)")
            self.adapter._initialized_tables.add(self.name)

    async def find_one(self, filter: dict, projection: dict = None) -> dict:
        await self._ensure_table()
        # Pre-filter for quick database search
        sql_conds = []
        sql_args = []
        arg_idx = 1
        for k, v in filter.items():
            if not k.startswith('$') and '.' not in k and not isinstance(v, dict):
                if k == '_id' or k == 'id':
                    sql_conds.append(f"id = ${arg_idx}")
                    sql_args.append(str(v) if v is not None else None)
                else:
                    sql_conds.append(f"data->>'{k}' = ${arg_idx}")
                    if isinstance(v, bool):
                        sql_args.append("true" if v else "false")
                    else:
                        sql_args.append(str(v) if v is not None else None)
                arg_idx += 1
                
        where_clause = " AND ".join(sql_conds)
        query = f"SELECT data FROM public.{self.name}"
        if where_clause:
            query += f" WHERE {where_clause}"
            
        rows = await fetch(query, *sql_args)
        for row in rows:
            doc = deserialize_doc(json.loads(row['data']))
            if match_document(doc, filter):
                return doc
        return None
        
    def find(self, filter: dict, projection: dict = None) -> PostgresCursor:
        return PostgresCursor(self.name, filter, self)
        
    async def create_index(self, *args, **kwargs):
        pass
        
    async def create_indexes(self, *args, **kwargs):
        pass

    async def insert_one(self, document: dict):
        await self._ensure_table()
        document = serialize_doc(document)
        if 'id' in document:
            doc_id = document['id']
        elif self.name == 'users':
            doc_id = document.get('user_id') or str(uuid.uuid4())
        elif self.name == 'user_sessions':
            doc_id = document.get('session_token') or str(uuid.uuid4())
        else:
            doc_id = str(uuid.uuid4())
        document['id'] = doc_id
        
        query = f"INSERT INTO public.{self.name} (id, data) VALUES ($1, $2)"
        await execute(query, doc_id, json.dumps(document))
        return document
        
    async def update_one(self, filter: dict, update: dict, upsert: bool = False):
        await self._ensure_table()
        doc = await self.find_one(filter)
        if doc is None:
            if upsert:
                new_doc = {}
                for k, v in filter.items():
                    if not k.startswith('$') and '.' not in k and not isinstance(v, dict):
                        new_doc[k] = v
                new_doc = apply_update(new_doc, update, is_insert=True)
                new_doc = serialize_doc(new_doc)
                if 'id' in new_doc:
                    doc_id = new_doc['id']
                elif self.name == 'users':
                    doc_id = new_doc.get('user_id') or str(uuid.uuid4())
                elif self.name == 'user_sessions':
                    doc_id = new_doc.get('session_token') or str(uuid.uuid4())
                else:
                    doc_id = str(uuid.uuid4())
                new_doc['id'] = doc_id
                
                query = f"INSERT INTO public.{self.name} (id, data) VALUES ($1, $2)"
                await execute(query, doc_id, json.dumps(new_doc))
                return UpdateResult(1, 1, doc_id)
            return UpdateResult(0, 0)
            
        updated_doc = apply_update(doc, update, is_insert=False)
        modified = 1 if updated_doc != doc else 0
        updated_doc = serialize_doc(updated_doc)
        doc_id = doc.get('id') or doc.get('user_id') or doc.get('session_token') or doc.get('scan_id') or doc.get('attempt_token') or str(uuid.uuid4())
        updated_doc['id'] = doc_id
        
        if self.name == 'users':
            query = f"UPDATE public.{self.name} SET data = $2, updated_at = now() WHERE id = $1"
        else:
            query = f"UPDATE public.{self.name} SET data = $2 WHERE id = $1"
            
        await execute(query, doc_id, json.dumps(updated_doc))
        return UpdateResult(1, modified)
        
    async def update_many(self, filter: dict, update: dict, upsert: bool = False):
        await self._ensure_table()
        cursor = self.find(filter)
        docs = await cursor.to_list(None)
        if not docs:
            if upsert:
                return await self.update_one(filter, update, upsert=True)
            return UpdateResult(0, 0)
            
        modified_count = 0
        for doc in docs:
            updated_doc = apply_update(doc, update, is_insert=False)
            if updated_doc != doc:
                modified_count += 1
            updated_doc = serialize_doc(updated_doc)
            doc_id = doc.get('id') or doc.get('user_id') or doc.get('session_token') or doc.get('scan_id') or doc.get('attempt_token') or str(uuid.uuid4())
            updated_doc['id'] = doc_id
            
            if self.name == 'users':
                query = f"UPDATE public.{self.name} SET data = $2, updated_at = now() WHERE id = $1"
            else:
                query = f"UPDATE public.{self.name} SET data = $2 WHERE id = $1"
            await execute(query, doc_id, json.dumps(updated_doc))
            
        return UpdateResult(len(docs), modified_count)
        
    async def delete_one(self, filter: dict):
        await self._ensure_table()
        doc = await self.find_one(filter)
        if doc is None:
            return DeleteResult(0)
        doc_id = doc.get('id') or doc.get('user_id') or doc.get('session_token') or doc.get('scan_id') or doc.get('attempt_token') or str(uuid.uuid4())
        query = f"DELETE FROM public.{self.name} WHERE id = $1"
        await execute(query, doc_id)
        return DeleteResult(1)
        
    async def delete_many(self, filter: dict):
        await self._ensure_table()
        cursor = self.find(filter)
        docs = await cursor.to_list(None)
        if not docs:
            return DeleteResult(0)
        deleted_count = 0
        for doc in docs:
            doc_id = doc.get('id') or doc.get('user_id') or doc.get('session_token') or doc.get('scan_id') or doc.get('attempt_token') or str(uuid.uuid4())
            query = f"DELETE FROM public.{self.name} WHERE id = $1"
            await execute(query, doc_id)
            deleted_count += 1
        return DeleteResult(deleted_count)
        
    async def count_documents(self, filter: dict) -> int:
        await self._ensure_table()
        cursor = self.find(filter)
        docs = await cursor.to_list(None)
        return len(docs)

    def aggregate(self, pipeline: list) -> PostgresAggregateCursor:
        return PostgresAggregateCursor(self, pipeline)


# Database Adapter Class replacing Motor AsyncIOMotorClient
class MongoToPostgresAdapter:
    def __init__(self):
        self._initialized_tables = set()

    def __getattr__(self, name: str) -> PostgresCollection:
        return PostgresCollection(name, self)
        
    def __getitem__(self, name: str) -> PostgresCollection:
        return PostgresCollection(name, self)
        
    async def list_collection_names(self) -> List[str]:
        query = """
            SELECT table_name 
            FROM information_schema.tables 
            WHERE table_schema = 'public'
        """
        rows = await fetch(query)
        return [r['table_name'] for r in rows]

# Export db adapter object
db = MongoToPostgresAdapter()


class User(BaseModel):
    model_config = ConfigDict(extra="ignore")
    user_id: str
    email: str
    name: str
    picture: Optional[str] = None
    created_at: Optional[Any] = None
    avatar_url: Optional[str] = None
    bio: Optional[str] = None
    role: str = "athlete"
    sport: str = "basketball"
    prq_score: float = 75.0
    verified_performance_prq: Optional[float] = None
    weight_kg: Optional[float] = None
    allergies: Optional[List[str]] = None
    dietary_restrictions: Optional[List[str]] = None
    date_of_birth: Optional[str] = None
    parental_consent_acknowledged: bool = False
    discovery_opt_in: Optional[bool] = None
    level: int = 1
    xp: int = 0
    streak_days: int = 0
    total_workouts: int = 0
    avatar_config: Optional[Dict] = None
    followers: List[str] = []
    following: List[str] = []
    coins: int = 100


async def verify_firebase_token(token: str) -> dict:
    use_emulator = (
        os.environ.get("FEL_USE_FIREBASE_EMULATORS") == "1" or
        os.environ.get("FIREBASE_AUTH_EMULATOR_HOST") is not None or
        os.environ.get("FEL_ENV") != "production"
    )
    
    if use_emulator:
        try:
            # Local/testing uses unsigned or dummy signed JWTs
            return jwt.decode(token, options={"verify_signature": False})
        except Exception as e:
            raise HTTPException(status_code=401, detail=f"Invalid emulator token: {e}")
            
    try:
        async with httpx.AsyncClient() as client:
            resp = await client.get("https://www.googleapis.com/robot/v1/metadata/x509/securetoken-system@system.gserviceaccount.com")
            public_keys = resp.json()
            
        unverified_header = jwt.get_unverified_header(token)
        kid = unverified_header.get("kid")
        if not kid or kid not in public_keys:
            raise HTTPException(status_code=401, detail="Invalid token kid")
            
        public_key = public_keys[kid]
        
        decoded = jwt.decode(
            token,
            public_key,
            algorithms=["RS256"],
            audience=FIREBASE_PROJECT_ID,
            issuer=f"https://securetoken.google.com/{FIREBASE_PROJECT_ID}"
        )
        return decoded
    except jwt.ExpiredSignatureError:
        raise HTTPException(status_code=401, detail="Token expired")
    except jwt.InvalidTokenError as e:
        raise HTTPException(status_code=401, detail=f"Invalid token: {e}")
    except Exception as e:
        raise HTTPException(status_code=401, detail=f"Token verification failed: {e}")


async def get_current_user(request: Request) -> User:
    session_token = request.cookies.get("session_token")
    if not session_token:
        auth_header = request.headers.get("Authorization")
        if auth_header and auth_header.startswith("Bearer "):
            session_token = auth_header.split(" ")[1]
            
    if not session_token:
        raise HTTPException(status_code=401, detail="Not authenticated")
        
    # Check if the token is a Firebase ID Token directly
    if session_token.count(".") == 2 and not session_token.startswith("sess_"):
        try:
            decoded = await verify_firebase_token(session_token)
            uid = decoded["sub"]
            user_doc = await db.users.find_one({"user_id": uid})
            if not user_doc:
                # Direct registration for first time Firebase users calling APIs directly
                email = decoded.get("email", f"{uid}@example.com")
                name = decoded.get("name", "Firebase User")
                picture = decoded.get("picture")
                user_doc = {
                    "user_id": uid, "email": email, "name": name,
                    "picture": picture, "created_at": datetime.now(timezone.utc).isoformat(),
                    "role": "athlete", "sport": "basketball", "prq_score": 75.0, "level": 1,
                    "xp": 0, "streak_days": 0, "total_workouts": 0, "coins": 100,
                    "followers": [], "following": [], "avatar_config": None
                }
                await db.users.insert_one(user_doc)
            return User(**user_doc)
        except Exception:
            raise HTTPException(status_code=401, detail="Invalid session or Firebase token")

    # Fallback to local session check
    session_doc = await db.user_sessions.find_one({"session_token": session_token})
    if not session_doc:
        raise HTTPException(status_code=401, detail="Invalid session")
        
    expires_at = session_doc["expires_at"]
    if isinstance(expires_at, str):
        expires_at = datetime.fromisoformat(expires_at)
    if expires_at.tzinfo is None:
        expires_at = expires_at.replace(tzinfo=timezone.utc)
    if expires_at < datetime.now(timezone.utc):
        raise HTTPException(status_code=401, detail="Session expired")
        
    user_doc = await db.users.find_one({"user_id": session_doc["user_id"]})
    if not user_doc:
        raise HTTPException(status_code=404, detail="User not found")
        
    return User(**user_doc)


class MockClient:
    def close(self):
        # Trigger pool close in background
        global db_pool
        if db_pool is not None:
            import asyncio
            try:
                loop = asyncio.get_running_loop()
                loop.create_task(db_pool.close())
            except RuntimeError:
                # No running event loop
                pass

client = MockClient()
