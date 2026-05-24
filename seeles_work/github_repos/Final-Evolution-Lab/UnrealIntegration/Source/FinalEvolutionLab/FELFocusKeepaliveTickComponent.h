// Optional: bind in Blueprint to UPixelStreaming2StreamerComponent::SendAllPlayersMessage for native PS2 path.
#pragma once

#include "CoreMinimal.h"
#include "Components/ActorComponent.h"
#include "FELFocusKeepaliveTickComponent.generated.h"

DECLARE_DYNAMIC_MULTICAST_DELEGATE(FFELKeepalivePulse);

UCLASS(ClassGroup = (Custom), meta = (BlueprintSpawnableComponent))
class UFELFocusKeepaliveTickComponent : public UActorComponent
{
	GENERATED_BODY()

public:
	UFELFocusKeepaliveTickComponent();

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Emergent")
	float IntervalSeconds = 0.5f;

	UPROPERTY(BlueprintAssignable, Category = "Emergent")
	FFELKeepalivePulse OnKeepalive;

	UFUNCTION(BlueprintCallable, Category = "Emergent")
	void SetKeepaliveEnabled(bool bEnable);

protected:
	virtual void EndPlay(const EEndPlayReason::Type EndPlayReason) override;

private:
	void Pulse();

	FTimerHandle Timer;
	bool bActive = false;
};
