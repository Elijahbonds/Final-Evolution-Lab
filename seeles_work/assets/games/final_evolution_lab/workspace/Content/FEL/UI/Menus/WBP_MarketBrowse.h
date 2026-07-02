// WBP_MarketBrowse.h — Market item grid with category filters and shard cost badges
#pragma once
#include "CoreMinimal.h"
#include "CommonActivatableWidget.h"
#include "WBP_MarketBrowse.generated.h"

USTRUCT(BlueprintType)
struct FFELMarketItem
{
    GENERATED_BODY()
    UPROPERTY(BlueprintReadOnly) FString ItemId;
    UPROPERTY(BlueprintReadOnly) FString DisplayName;
    UPROPERTY(BlueprintReadOnly) FString Category;
    UPROPERTY(BlueprintReadOnly) FString ThumbnailUrl;
    UPROPERTY(BlueprintReadOnly) int32 ShardCost = 0;
    UPROPERTY(BlueprintReadOnly) bool bOwned = false;
};

UCLASS()
class FINALEVOLUTIONLAB_API UWBP_MarketBrowse : public UCommonActivatableWidget
{
    GENERATED_BODY()
public:
    UPROPERTY(BlueprintReadOnly, Category = "FEL|Market")
    TArray<FFELMarketItem> MarketItems;

    UPROPERTY(BlueprintReadWrite, Category = "FEL|Market")
    FString ActiveCategoryFilter;

    UFUNCTION(BlueprintCallable, Category = "FEL|Menu")
    void OnFilterChanged(const FString& Category);

    UFUNCTION(BlueprintCallable, Category = "FEL|Menu")
    void OnItemPurchasePressed(const FString& ItemId);

protected:
    virtual void NativeOnActivated() override;
};
