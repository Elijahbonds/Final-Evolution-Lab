// Copyright (c) Final Evolution Lab.

#include "FELVaultDatabase.h"

#include "FELBasketballGameState.h"

#include "HAL/FileManager.h"
#include "Misc/DateTime.h"
#include "SQLitePreparedStatement.h"

FELVaultDatabase::~FELVaultDatabase()
{
	Close();
}

bool FELVaultDatabase::Open(const FString& AbsoluteDatabasePath)
{
	Close();

	Db = MakeUnique<FSQLiteDatabase>();
	if (!Db->Open(*AbsoluteDatabasePath, ESQLiteDatabaseOpenMode::ReadWriteCreate))
	{
		Db.Reset();
		return false;
	}

	if (!EnsureSchema())
	{
		return false;
	}
	// Idempotent: may fail on first run with an already-migrated DB; safe to ignore.
	(void)Db->Execute(
		TEXT("ALTER TABLE vault_samples ADD COLUMN prq_authenticity TEXT DEFAULT 'AUTHENTICATED';"));
	return true;
}

void FELVaultDatabase::Close()
{
	if (Db.IsValid())
	{
		Db->Close();
		Db.Reset();
	}
}

bool FELVaultDatabase::EnsureSchema()
{
	if (!Db.IsValid() || !Db->IsValid())
	{
		return false;
	}

	static const TCHAR* Schema = TEXT(
		"CREATE TABLE IF NOT EXISTS vault_samples ("
		"id INTEGER PRIMARY KEY AUTOINCREMENT,"
		"t_unix INTEGER NOT NULL,"
		"prq REAL NOT NULL,"
		"combo_streak INTEGER NOT NULL,"
		"combo_meter REAL NOT NULL,"
		"buckets INTEGER NOT NULL,"
		"arena_game_mode_id TEXT NOT NULL"
		");");

	if (!Db->Execute(Schema))
	{
		return false;
	}
	static const TCHAR* DraftSchema = TEXT(
		"CREATE TABLE IF NOT EXISTS draft_card_activations ("
		"id INTEGER PRIMARY KEY AUTOINCREMENT,"
		"t_unix INTEGER NOT NULL,"
		"card_id TEXT NOT NULL,"
		"draft_year INTEGER NOT NULL,"
		"pathway TEXT NOT NULL,"
		"serial_id TEXT NOT NULL,"
		"signature_hex TEXT NOT NULL,"
		"commissioner_mint INTEGER NOT NULL DEFAULT 0"
		");");
	if (!Db->Execute(DraftSchema))
	{
		return false;
	}
	(void)Db->Execute(TEXT(
		"CREATE UNIQUE INDEX IF NOT EXISTS idx_draft_unique ON draft_card_activations(card_id, draft_year, serial_id);"));

	static const TCHAR* ShardSchema = TEXT(
		"CREATE TABLE IF NOT EXISTS shard_ledger ("
		"id INTEGER PRIMARY KEY AUTOINCREMENT,"
		"t_unix INTEGER NOT NULL,"
		"delta INTEGER NOT NULL,"
		"reason TEXT NOT NULL,"
		"ref_meal_id TEXT,"
		"recommended INTEGER NOT NULL DEFAULT 0"
		");");
	if (!Db->Execute(ShardSchema))
	{
		return false;
	}
	return true;
}

bool FELVaultDatabase::InsertSample(const AFELBasketballGameState* GS, const FString& PrqAuthenticity)
{
	if (!GS || !Db.IsValid() || !Db->IsValid())
	{
		return false;
	}

	FString Arena = GS->GetArenaGameModeId();
	Arena.ReplaceInline(TEXT("'"), TEXT("''"));

	FString Auth = PrqAuthenticity.IsEmpty() ? TEXT("AUTHENTICATED") : PrqAuthenticity;
	Auth.ReplaceInline(TEXT("'"), TEXT("''"));

	const FString Sql = FString::Printf(
		TEXT("INSERT INTO vault_samples (t_unix, prq, combo_streak, combo_meter, buckets, arena_game_mode_id, prq_authenticity) VALUES (%lld, %.6f, %d, %.6f, %d, '%s', '%s');"),
		static_cast<long long>(FDateTime::UtcNow().ToUnixTimestamp()),
		GS->GetTelemetryPRQ(),
		GS->GetComboStreak(),
		GS->GetComboMeter01(),
		GS->GetScore(),
		*Arena,
		*Auth);

	return Db->Execute(*Sql);
}

bool FELVaultDatabase::TryQueryRecentVaultRows(int32 MaxRows, TArray<FFELVaultRow>& OutRows) const
{
	OutRows.Reset();
	if (!Db.IsValid() || !Db->IsValid())
	{
		return false;
	}
	const int32 Limit = FMath::Clamp(MaxRows, 1, 250);
	const FString Sql = FString::Printf(
		TEXT("SELECT t_unix, prq, buckets, arena_game_mode_id FROM vault_samples ORDER BY id DESC LIMIT %d"),
		Limit);

	const int64 Num = Db->Execute(
		*Sql,
		[&OutRows](const FSQLitePreparedStatement& Stmt) -> ESQLitePreparedStatementExecuteRowResult
		{
			FFELVaultRow Row;
			int64 Tu = 0;
			double Prq = 0.0;
			int32 Buckets = 0;
			FString Arena;
			if (Stmt.GetColumnValueByIndex(0, Tu) && Stmt.GetColumnValueByIndex(1, Prq)
				&& Stmt.GetColumnValueByIndex(2, Buckets) && Stmt.GetColumnValueByIndex(3, Arena))
			{
				Row.TUnix = Tu;
				Row.Prq = Prq;
				Row.Buckets = Buckets;
				Row.ArenaGameModeId = Arena;
				OutRows.Add(Row);
			}
			return ESQLitePreparedStatementExecuteRowResult::Continue;
		});

	return Num != INDEX_NONE;
}

bool FELVaultDatabase::InsertDraftActivation(
	const FString& CardId,
	int32 DraftYear,
	const FString& Pathway,
	const FString& SerialId,
	const FString& SignatureHex,
	bool bCommissionerMint)
{
	if (!Db.IsValid() || !Db->IsValid())
	{
		return false;
	}
	FString C = CardId;
	FString P = Pathway;
	FString S = SerialId;
	FString G = SignatureHex;
	C.ReplaceInline(TEXT("'"), TEXT("''"));
	P.ReplaceInline(TEXT("'"), TEXT("''"));
	S.ReplaceInline(TEXT("'"), TEXT("''"));
	G.ReplaceInline(TEXT("'"), TEXT("''"));

	const FString Sql = FString::Printf(
		TEXT("INSERT OR REPLACE INTO draft_card_activations (t_unix, card_id, draft_year, pathway, serial_id, signature_hex, commissioner_mint) VALUES (%lld, '%s', %d, '%s', '%s', '%s', %d);"),
		static_cast<long long>(FDateTime::UtcNow().ToUnixTimestamp()),
		*C,
		DraftYear,
		*P,
		*S,
		*G,
		bCommissionerMint ? 1 : 0);

	return Db->Execute(*Sql);
}

bool FELVaultDatabase::TryQueryDraftActivations(
	int32 OptionalDraftYear,
	const FString& OptionalPathwaySubstring,
	int32 MaxRows,
	TArray<FFELDraftCardRow>& OutRows) const
{
	OutRows.Reset();
	if (!Db.IsValid() || !Db->IsValid())
	{
		return false;
	}
	const int32 Limit = FMath::Clamp(MaxRows, 1, 500);

	FString Sql = TEXT(
		"SELECT t_unix, card_id, draft_year, pathway, serial_id, commissioner_mint FROM draft_card_activations WHERE 1=1");
	if (OptionalDraftYear > 0)
	{
		Sql += FString::Printf(TEXT(" AND draft_year=%d"), OptionalDraftYear);
	}
	if (!OptionalPathwaySubstring.IsEmpty())
	{
		FString Esc = OptionalPathwaySubstring;
		Esc.ReplaceInline(TEXT("'"), TEXT("''"));
		Sql += FString::Printf(TEXT(" AND pathway='%s'"), *Esc);
	}
	Sql += FString::Printf(TEXT(" ORDER BY id DESC LIMIT %d"), Limit);

	const int64 Num = Db->Execute(
		*Sql,
		[&OutRows](const FSQLitePreparedStatement& Stmt) -> ESQLitePreparedStatementExecuteRowResult
		{
			FFELDraftCardRow Row;
			int64 Tu = 0;
			FString Ci, Pa, Se;
			int32 Y = 0;
			int32 Comm = 0;
			if (Stmt.GetColumnValueByIndex(0, Tu) && Stmt.GetColumnValueByIndex(1, Ci) && Stmt.GetColumnValueByIndex(2, Y)
				&& Stmt.GetColumnValueByIndex(3, Pa) && Stmt.GetColumnValueByIndex(4, Se) && Stmt.GetColumnValueByIndex(5, Comm))
			{
				Row.TUnix = Tu;
				Row.CardId = Ci;
				Row.DraftYear = Y;
				Row.Pathway = Pa;
				Row.SerialId = Se;
				Row.bCommissionerMint = Comm != 0;
				OutRows.Add(Row);
			}
			return ESQLitePreparedStatementExecuteRowResult::Continue;
		});

	return Num != INDEX_NONE;
}

bool FELVaultDatabase::InsertShardLedgerEntry(
	const int32 Delta,
	const FString& Reason,
	const FString& RefMealId,
	const bool bRecommendedPick)
{
	if (!Db.IsValid() || !Db->IsValid())
	{
		return false;
	}
	FString R = Reason;
	FString M = RefMealId;
	R.ReplaceInline(TEXT("'"), TEXT("''"));
	M.ReplaceInline(TEXT("'"), TEXT("''"));

	const FString Sql = FString::Printf(
		TEXT("INSERT INTO shard_ledger (t_unix, delta, reason, ref_meal_id, recommended) VALUES (%lld, %d, '%s', '%s', %d);"),
		static_cast<long long>(FDateTime::UtcNow().ToUnixTimestamp()),
		Delta,
		*R,
		*M,
		bRecommendedPick ? 1 : 0);

	return Db->Execute(*Sql);
}

bool FELVaultDatabase::TrySumShardLedger(int64& OutTotal) const
{
	OutTotal = 0;
	if (!Db.IsValid() || !Db->IsValid())
	{
		return false;
	}
	const FString Sql = TEXT("SELECT COALESCE(SUM(delta), 0) FROM shard_ledger;");
	const int64 Num = Db->Execute(
		*Sql,
		[&OutTotal](const FSQLitePreparedStatement& Stmt) -> ESQLitePreparedStatementExecuteRowResult
		{
			double Sum = 0.0;
			if (Stmt.GetColumnValueByIndex(0, Sum))
			{
				OutTotal = static_cast<int64>(FMath::RoundToDouble(Sum));
			}
			return ESQLitePreparedStatementExecuteRowResult::Continue;
		});
	return Num != INDEX_NONE;
}
