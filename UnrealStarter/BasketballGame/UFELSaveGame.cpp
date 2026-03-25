// Copyright (c) Final Evolution Lab.

#include "UFELSaveGame.h"
#include "Math/UnrealMathUtility.h"
#include "Dom/JsonObject.h"
#include "Dom/JsonValue.h"
#include "Misc/Base64.h"
#include "Serialization/JsonSerializer.h"
#include "Serialization/JsonWriter.h"

namespace
{
/** Sample variance of last N JumpHeight values (population-style / n divisor per window size). */
static float FEL_LastNJumpHeightSampleVariance(const TArray<FFELAthleteStats>& H, const int32 N, const int32 EndExclusiveIndex)
{
	if (H.Num() < N || EndExclusiveIndex < N || EndExclusiveIndex > H.Num())
	{
		return 0.f;
	}
	float Sum = 0.f;
	for (int32 i = EndExclusiveIndex - N; i < EndExclusiveIndex; ++i)
	{
		Sum += H[i].JumpHeight;
	}
	const float Mean = Sum / static_cast<float>(N);
	float VarAcc = 0.f;
	for (int32 i = EndExclusiveIndex - N; i < EndExclusiveIndex; ++i)
	{
		const float D = H[i].JumpHeight - Mean;
		VarAcc += D * D;
	}
	// Sample variance (n-1) when n>1 — stabilizes small windows.
	return (N > 1) ? (VarAcc / static_cast<float>(N - 1)) : 0.f;
}

static void FEL_XORObfuscateBytes(TArray<uint8>& Bytes)
{
	static const char Key[] = "FELUniversalMaster1.0";
	const int32 KLen = static_cast<int32>(sizeof(Key) - 1);
	for (int32 i = 0; i < Bytes.Num(); ++i)
	{
		Bytes[i] = static_cast<uint8>(static_cast<int32>(Bytes[i]) ^ static_cast<int32>(Key[i % KLen]));
	}
}
} // namespace

EFELFatigueState UFELSaveGame::GetJumpPerformanceTrend(const UFELSaveGame* Save)
{
	if (!Save || Save->PerformanceHistory.Num() < 20)
	{
		return EFELFatigueState::Unknown;
	}

	const TArray<FFELAthleteStats>& H = Save->PerformanceHistory;
	const int32 N = H.Num();

	// Sample variance of last 10 JumpHeight (uu²/s²). >15 => inconclusive (no fatigue UX). For a stdev gate, compare sqrt(VarRecent).
	const float VarRecent = FEL_LastNJumpHeightSampleVariance(H, 10, N);
	if (VarRecent > 15.0f)
	{
		return EFELFatigueState::Inconclusive;
	}

	float SumRecent = 0.f;
	float SumPrior = 0.f;
	for (int32 i = 0; i < 10; ++i)
	{
		SumRecent += H[N - 10 + i].JumpHeight;
	}
	for (int32 i = 0; i < 10; ++i)
	{
		SumPrior += H[N - 20 + i].JumpHeight;
	}

	const float AvgRecent = SumRecent / 10.f;
	const float AvgPrior = SumPrior / 10.f;
	if (AvgPrior <= KINDA_SMALL_NUMBER)
	{
		return EFELFatigueState::Unknown;
	}

	if (AvgRecent < AvgPrior * 0.95f)
	{
		return EFELFatigueState::Fatigued;
	}

	return EFELFatigueState::Normal;
}

float UFELSaveGame::GetAllTimePeakJumpZVelocity(const UFELSaveGame* Save)
{
	if (!Save)
	{
		return 0.f;
	}
	float M = 0.f;
	for (const FFELAthleteStats& Row : Save->PerformanceHistory)
	{
		M = FMath::Max(M, Row.JumpHeight);
	}
	return M;
}

bool UFELSaveGame::Validation_StressTest_IsDataCompromised(const FFELReadinessSnapshot& S, const float PeakJumpZVelocityUu)
{
	// Biometric scale (SHIP_CRITERIA — avatar parity with Swift `AvatarSkinConfig`).
	const double HS = S.AvatarHeightScale;
	const double WS = S.AvatarWeightScale;
	if (HS < 0.4 || HS > 2.2 || WS < 0.4 || WS > 2.2)
	{
		return true;
	}

	const bool bHaveFlightScan = S.FlightTimeSeconds > 0.05 && S.FlightTimeSeconds < 3.0;
	const bool bHaveVerticalScan = S.VerticalEstimateInches > 5.0 && S.VerticalEstimateInches < 60.0;
	if (!bHaveFlightScan && !bHaveVerticalScan)
	{
		return false;
	}

	// UE default gravity magnitude (cm/s^2) — matches `AUDIT` biomechanical vertical flight model for twin parity.
	constexpr float G = 980.f;
	// Symmetric vertical hop: T = 2*v0/g  =>  v0 = g*T/2 (launch speed consistent with measured hang time).
	if (bHaveFlightScan)
	{
		const float VFromFlightTime = static_cast<float>(0.5 * G * S.FlightTimeSeconds);
		const float Den = FMath::Max(120.f, VFromFlightTime);
		const float Rel = FMath::Abs(PeakJumpZVelocityUu - VFromFlightTime) / Den;
		if (Rel > 0.45f)
		{
			return true;
		}
	}
	// Energy height: v = sqrt(2 g h) with h from scan vertical estimate (cm).
	if (bHaveVerticalScan)
	{
		const float Hcm = static_cast<float>(S.VerticalEstimateInches * 2.54);
		const float VFromHeight = FMath::Sqrt(2.f * G * Hcm);
		const float Den2 = FMath::Max(120.f, VFromHeight);
		const float Rel2 = FMath::Abs(PeakJumpZVelocityUu - VFromHeight) / Den2;
		if (Rel2 > 0.55f)
		{
			return true;
		}
	}
	return false;
}

FString UFELSaveGame::ExportSaveToJSON(const UFELSaveGame* Save)
{
	if (!Save)
	{
		return FString();
	}

	float AllTimePeakZ = GetAllTimePeakJumpZVelocity(Save);

	TSharedPtr<FJsonObject> Root = MakeShared<FJsonObject>();
	Root->SetNumberField(TEXT("allTimePeakZ"), static_cast<double>(AllTimePeakZ));
	Root->SetStringField(TEXT("schemaVersion"), TEXT("FELUniversalMaster-1"));

	TArray<TSharedPtr<FJsonValue>> SkinVals;
	SkinVals.Reserve(Save->UnlockedSovereignSkins.Num());
	for (const FString& S : Save->UnlockedSovereignSkins)
	{
		SkinVals.Add(MakeShared<FJsonValueString>(S));
	}
	Root->SetArrayField(TEXT("unlockedSovereignSkins"), SkinVals);

	TArray<TSharedPtr<FJsonValue>> HistVals;
	HistVals.Reserve(Save->PerformanceHistory.Num());
	for (const FFELAthleteStats& Row : Save->PerformanceHistory)
	{
		TSharedPtr<FJsonObject> O = MakeShared<FJsonObject>();
		O->SetNumberField(TEXT("jumpHeight"), static_cast<double>(Row.JumpHeight));
		O->SetStringField(TEXT("gearId"), Row.GearID);
		O->SetStringField(TEXT("timestampUtc"), Row.Timestamp.ToString(TEXT("%Y-%m-%dT%H:%M:%SZ")));
		HistVals.Add(MakeShared<FJsonValueObject>(O));
	}
	Root->SetArrayField(TEXT("performanceHistory"), HistVals);

	FString JsonPlain;
	const TSharedRef<TJsonWriter<>> Writer = TJsonWriterFactory<>::Create(&JsonPlain);
	if (!FJsonSerializer::Serialize(Root.ToSharedRef(), Writer))
	{
		return FString();
	}

	const FTCHARToUTF8 Utf8(*JsonPlain);
	TArray<uint8> Bytes;
	Bytes.Append(reinterpret_cast<const uint8*>(Utf8.Get()), Utf8.Length());
	FEL_XORObfuscateBytes(Bytes);
	return FBase64::Encode(Bytes);
}
