import asyncio
from datetime import datetime, timezone, timedelta
from core import db, init_db, get_db_pool

async def main():
    # Initialize the PostgreSQL pool
    await init_db()
    
    print("Cleaning existing test users and sessions from PostgreSQL...")
    await db.users.delete_many({"user_id": {"$in": ["test-fel-os-1777958291132", "test-fel-os-lowprq", "test-fel-os-1777957943281"]}})
    await db.user_sessions.delete_many({"session_token": {"$in": ["sess_edu_1777958291132", "sess_lowprq_1777958291132", "sess_1777957943281"]}})
    await db.education_progress.delete_many({"user_id": {"$in": ["test-fel-os-1777958291132", "test-fel-os-lowprq", "test-fel-os-1777957943281"]}})
    await db.bio_digital_progress.delete_many({"user_id": {"$in": ["test-fel-os-1777958291132", "test-fel-os-lowprq", "test-fel-os-1777957943281"]}})
    await db.prq_metrics.delete_many({"user_id": {"$in": ["test-fel-os-1777958291132", "test-fel-os-lowprq", "test-fel-os-1777957943281"]}})

    # 1. Seed user 1: FRESH_TOKEN ("sess_edu_1777958291132"), User ID "test-fel-os-1777958291132"
    # Has verified_performance_prq = 82.0 (so meets threshold of >= 80)
    # No progress (fresh)
    print("Seeding fresh test user...")
    await db.users.insert_one({
        "user_id": "test-fel-os-1777958291132",
        "email": "test-edu-fresh@example.com",
        "name": "Fresh Test User",
        "role": "athlete",
        "sport": "basketball",
        "prq_score": 82.0,
        "verified_performance_prq": 82.0,
        "level": 1,
        "xp": 0,
        "streak_days": 0,
        "total_workouts": 0,
        "coins": 100,
        "followers": [],
        "following": [],
        "created_at": datetime.now(timezone.utc).isoformat()
    })
    await db.user_sessions.insert_one({
        "user_id": "test-fel-os-1777958291132",
        "session_token": "sess_edu_1777958291132",
        "expires_at": (datetime.now(timezone.utc) + timedelta(days=7)).isoformat(),
        "created_at": datetime.now(timezone.utc).isoformat()
    })

    # 2. Seed user 2: LOWPRQ_TOKEN ("sess_lowprq_1777958291132"), User ID "test-fel-os-lowprq"
    # Has verified_performance_prq = 60.0 (fails threshold)
    # No progress
    print("Seeding low PRQ test user...")
    await db.users.insert_one({
        "user_id": "test-fel-os-lowprq",
        "email": "test-lowprq@example.com",
        "name": "Low PRQ Test User",
        "role": "athlete",
        "sport": "basketball",
        "prq_score": 60.0,
        "verified_performance_prq": 60.0,
        "level": 1,
        "xp": 0,
        "streak_days": 0,
        "total_workouts": 0,
        "coins": 100,
        "followers": [],
        "following": [],
        "created_at": datetime.now(timezone.utc).isoformat()
    })
    await db.user_sessions.insert_one({
        "user_id": "test-fel-os-lowprq",
        "session_token": "sess_lowprq_1777958291132",
        "expires_at": (datetime.now(timezone.utc) + timedelta(days=7)).isoformat(),
        "created_at": datetime.now(timezone.utc).isoformat()
    })

    # 3. Seed user 3: EXISTING_TOKEN ("sess_1777957943281"), User ID "test-fel-os-1777957943281"
    # Has certificate already issued, verified_performance_prq = 82.0
    # Has all Kinesiology coursework completed
    # Has all Bio-digital modules completed
    # Has final assessment passed
    print("Seeding existing cert test user...")
    await db.users.insert_one({
        "user_id": "test-fel-os-1777957943281",
        "email": "test-existing@example.com",
        "name": "Existing Cert User",
        "role": "athlete",
        "sport": "basketball",
        "prq_score": 82.0,
        "verified_performance_prq": 82.0,
        "level": 1,
        "xp": 1000,
        "streak_days": 0,
        "total_workouts": 0,
        "coins": 100,
        "followers": [],
        "following": [],
        "created_at": datetime.now(timezone.utc).isoformat()
    })
    await db.user_sessions.insert_one({
        "user_id": "test-fel-os-1777957943281",
        "session_token": "sess_1777957943281",
        "expires_at": (datetime.now(timezone.utc) + timedelta(days=7)).isoformat(),
        "created_at": datetime.now(timezone.utc).isoformat()
    })
    await db.bio_digital_progress.insert_one({
        "user_id": "test-fel-os-1777957943281",
        "modules_completed": ["skeletal_basics", "muscular_chains", "kinetic_chain_pillars", "neural_priming"],
        "updated_at": datetime.now(timezone.utc).isoformat()
    })
    await db.education_progress.insert_one({
        "user_id": "test-fel-os-1777957943281",
        "track_id": "kinesiology",
        "completed_lessons": ["kin_bio_1", "kin_mus_1", "kin_ms_1", "kin_inj_1", "kin_per_1", "kin_neu_1", "kin_rec_1", "kin_eth_1"],
        "final_passed": True,
        "final_verified_receipt": "receipt_existing_cert_12345",
        "certificate_issued": True,
        "certificate_id": "FEL-AK-EXISTING",
        "issued_at": datetime.now(timezone.utc).isoformat(),
        "updated_at": datetime.now(timezone.utc).isoformat()
    })

    # Clean up coaches and video
    await db.users.delete_many({"user_id": {"$in": ["coach_1", "coach_2", "coach_3", "coach_4"]}})
    await db.videos.delete_many({"id": "test_video_123"})
    await db.critiques.delete_many({"video_id": "test_video_123"})

    # Seed coaches
    print("Seeding coach users...")
    await db.users.insert_one({
        "user_id": "coach_1",
        "email": "coach1@example.com",
        "name": "Coach Williams",
        "role": "coach",
        "sport": "basketball",
        "specialty": "Shooting & Ball Handling",
        "rating": 4.8,
        "sessions": 250,
        "rate": 25,
        "created_at": datetime.now(timezone.utc).isoformat()
    })
    await db.users.insert_one({
        "user_id": "coach_2",
        "email": "coach2@example.com",
        "name": "Sensei Tanaka",
        "role": "coach",
        "sport": "karate",
        "specialty": "Traditional Karate",
        "rating": 4.9,
        "sessions": 180,
        "rate": 35,
        "created_at": datetime.now(timezone.utc).isoformat()
    })
    await db.users.insert_one({
        "user_id": "coach_3",
        "email": "coach3@example.com",
        "name": "Coach Martinez",
        "role": "coach",
        "sport": "soccer",
        "specialty": "Footwork & Strategy",
        "rating": 4.7,
        "sessions": 320,
        "rate": 20,
        "created_at": datetime.now(timezone.utc).isoformat()
    })
    await db.users.insert_one({
        "user_id": "coach_4",
        "email": "coach4@example.com",
        "name": "Dr. Sarah Chen",
        "role": "coach",
        "sport": "training",
        "specialty": "Sports Psychology",
        "rating": 5.0,
        "sessions": 150,
        "rate": 50,
        "created_at": datetime.now(timezone.utc).isoformat()
    })

    # Seed video
    print("Seeding test video...")
    await db.videos.insert_one({
        "id": "test_video_123",
        "user_id": "test-fel-os-1777957943281",
        "filename": "test_shoot.mp4",
        "sport": "basketball",
        "url": "https://example.com/test_shoot.mp4",
        "created_at": datetime.now(timezone.utc).isoformat()
    })

    print("PostgreSQL Database Seeding Completed Successfully.")
    
    # Close connection pool
    pool = await get_db_pool()
    await pool.close()

if __name__ == "__main__":
    asyncio.run(main())
