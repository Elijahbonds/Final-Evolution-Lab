// Copy into your game's Source/FinalEvolutionLab/ module.
#pragma once

#include "CoreMinimal.h"
#include "Subsystems/GameInstanceSubsystem.h"
#include "Engine/TimerHandle.h"

#include "FELPerformanceManagerSubsystem.generated.h"

UENUM(BlueprintType)
enum class EFELThermalBucket : uint8
{
	Nominal UMETA(DisplayName = "Nominal"),
	Fair UMETA(DisplayName = "Fair"),
	Serious UMETA(DisplayName = "Serious"),
	Critical UMETA(DisplayName = "Critical"),
};

/**
 * iOS performance guardrails:
 * - Detect device model (hw.machine via FPlatformMisc::GetDeviceModel()) for tiering.
 * - Poll thermal state every 30s and dynamically lower resolution scalars to reduce throttling.
 *
 * This is intentionally conservative and UE-native (no Swift dependency).
 */
UCLASS()
class UFELPerformanceManagerSubsystem : public UGameInstanceSubsystem
{
	GENERATED_BODY()

public:
	virtual void Initialize(FSubsystemCollectionBase& Collection) override;
	virtual void Deinitialize() override;

	/** Force an immediate re-application of the current perf settings. */
	UFUNCTION(BlueprintCallable, Category = "FEL|Performance")
	void ApplyNow();

	/** Optionally prewarm assets (maps/blueprints/meshes) referenced by soft paths. */
	UFUNCTION(BlueprintCallable, Category = "FEL|Performance")
	void PrewarmSoftPaths(const TArray<FSoftObjectPath>& AssetsToLoad);

	/** Convenience: prewarm your two most common maps. */
	UFUNCTION(BlueprintCallable, Category = "FEL|Performance")
	void PrewarmCoreVenues();

	UFUNCTION(BlueprintPure, Category = "FEL|Performance")
	FString GetDeviceModelString() const { return DeviceModel; }

	UFUNCTION(BlueprintPure, Category = "FEL|Performance")
	EFELThermalBucket GetThermalBucket() const { return ThermalBucket; }

private:
	void TickThermal();
	void ApplyScalars(float MobileContentScaleFactor, float ScreenPercentage, const TCHAR* Reason);

	static EFELThermalBucket MapTemperatureLevelToBucket(int32 LevelInt);
	static bool IsLikelyIPhoneProMaxTier(const FString& Model);

	FString DeviceModel;
	EFELThermalBucket ThermalBucket = EFELThermalBucket::Nominal;

	FTimerHandle ThermalTimer;
	TSharedPtr<struct FStreamableHandle> PrewarmHandle;
};

