// FELBackendConfig.h — shared HTTP/WS endpoint resolution from DefaultGame.ini [FELBackend]
#pragma once

#include "CoreMinimal.h"
#include "HAL/PlatformMisc.h"
#include "Misc/ConfigCacheIni.h"
#include "Misc/Paths.h"

namespace FELBackendConfig
{
	inline void LoadBackendString(const TCHAR* Key, FString& OutValue)
	{
		OutValue.TrimStartAndEndInline();
		if (GConfig->GetString(TEXT("FELBackend"), Key, OutValue, GGameIni))
		{
			OutValue.TrimStartAndEndInline();
		}
	}

	inline FString ApiBaseUrl()
	{
		FString Base = TEXT("https://finalevolutiongroup.com");
		LoadBackendString(TEXT("ApiBaseUrl"), Base);
		while (Base.EndsWith(TEXT("/")))
		{
			Base.LeftChopInline(1);
		}
		return Base;
	}

	inline FString JoinUrl(const FString& Base, const FString& Path)
	{
		FString NormalizedPath = Path;
		if (!NormalizedPath.StartsWith(TEXT("/")))
		{
			NormalizedPath = TEXT("/") + NormalizedPath;
		}
		return Base + NormalizedPath;
	}

	inline FString ResolveSessionReceiptUrl()
	{
		FString Url;
		LoadBackendString(TEXT("SessionReceiptUrl"), Url);
		if (!Url.IsEmpty())
		{
			const FString EnvUrl = FPlatformMisc::GetEnvironmentVariable(TEXT("FEL_SESSION_RECEIPT_URL")).TrimStartAndEnd();
			return EnvUrl.IsEmpty() ? Url : EnvUrl;
		}

		FString Path = TEXT("/api/games/session");
		LoadBackendString(TEXT("SessionReceiptPath"), Path);
		Url = JoinUrl(ApiBaseUrl(), Path);

		const FString EnvUrl = FPlatformMisc::GetEnvironmentVariable(TEXT("FEL_SESSION_RECEIPT_URL")).TrimStartAndEnd();
		if (!EnvUrl.IsEmpty())
		{
			Url = EnvUrl;
		}
		return Url;
	}

	inline FString ResolveHudWebSocketUrl()
	{
		const FString EnvUrl = FPlatformMisc::GetEnvironmentVariable(TEXT("FEL_HUD_WS_URL")).TrimStartAndEnd();
		if (!EnvUrl.IsEmpty())
		{
			return EnvUrl;
		}

		FString Url = TEXT("ws://127.0.0.1:8787/ws/hud");
		LoadBackendString(TEXT("HudWebSocketUrl"), Url);
		if (Url.IsEmpty())
		{
			Url = TEXT("ws://127.0.0.1:8787/ws/hud");
		}

		FString UserId = TEXT("anonymous");
		LoadBackendString(TEXT("HudUserId"), UserId);
		if (UserId.IsEmpty())
		{
			UserId = TEXT("anonymous");
		}

		if (!Url.Contains(TEXT("user_id="), ESearchCase::IgnoreCase))
		{
			const TCHAR Separator = Url.Contains(TEXT("?")) ? TEXT('&') : TEXT('?');
			Url += FString::Printf(TEXT("%cuser_id=%s"), Separator, *UserId);
		}
		return Url;
	}

	inline FString ResolveApiUrl(const FString& ApiPath)
	{
		FString Path = ApiPath;
		if (!Path.StartsWith(TEXT("/")))
		{
			Path = TEXT("/") + Path;
		}
		if (!Path.StartsWith(TEXT("/api/"), ESearchCase::IgnoreCase))
		{
			Path = TEXT("/api") + Path;
		}
		return JoinUrl(ApiBaseUrl(), Path);
	}
}
