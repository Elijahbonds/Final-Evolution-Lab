// Copyright (c) Final Evolution Lab.

#pragma once

#include "CoreMinimal.h"
#include "FELCreatorCardTypes.h"
#include "FELVaultTypes.h"
#include "SQLiteDatabase.h"

class AFELBasketballGameState;

/** Local SQLite store under Saved/Vault (PRQ, combo, buckets). */
class FELVaultDatabase
{
public:
	~FELVaultDatabase();

	bool Open(const FString& AbsoluteDatabasePath);
	void Close();

	bool InsertSample(const AFELBasketballGameState* GS, const FString& PrqAuthenticity = TEXT("AUTHENTICATED"));

	bool TryQueryRecentVaultRows(int32 MaxRows, TArray<FFELVaultRow>& OutRows) const;

	bool InsertDraftActivation(
		const FString& CardId,
		int32 DraftYear,
		const FString& Pathway,
		const FString& SerialId,
		const FString& SignatureHex,
		bool bCommissionerMint);

	bool TryQueryDraftActivations(
		int32 OptionalDraftYear,
		const FString& OptionalPathwaySubstring,
		int32 MaxRows,
		TArray<FFELDraftCardRow>& OutRows) const;

	/** Append-only Evolution Shards ledger (fuel orders, hub rewards). */
	bool InsertShardLedgerEntry(
		int32 Delta,
		const FString& Reason,
		const FString& RefMealId,
		bool bRecommendedPick);

	bool TrySumShardLedger(int64& OutTotal) const;

	bool IsOpen() const { return Db && Db->IsValid(); }

private:
	bool EnsureSchema();

	TUniquePtr<FSQLiteDatabase> Db;
};
