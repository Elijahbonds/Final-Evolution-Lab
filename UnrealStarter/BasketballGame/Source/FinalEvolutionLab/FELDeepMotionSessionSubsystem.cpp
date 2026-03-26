// Copyright (c) Final Evolution Lab.

#include "FELDeepMotionSessionSubsystem.h"
#include "HttpModule.h"
#include "Interfaces/IHttpRequest.h"
#include "Interfaces/IHttpResponse.h"
#include "Containers/Array.h"
#include "Misc/Base64.h"
#include "HAL/PlatformProcess.h"

void UFELDeepMotionSessionSubsystem::Initialize(FSubsystemCollectionBase& Collection)
{
	Super::Initialize(Collection);
	RefreshCredentialsFromEnvironment();
}

void UFELDeepMotionSessionSubsystem::RefreshCredentialsFromEnvironment()
{
	ClientId = FPlatformMisc::GetEnvironmentVariable(TEXT("DEEPMOTION_CLIENT_ID")).TrimStartAndEnd();
	ClientSecret = FPlatformMisc::GetEnvironmentVariable(TEXT("DEEPMOTION_CLIENT_SECRET")).TrimStartAndEnd();
}

FString UFELDeepMotionSessionSubsystem::GetCookieHeaderValue() const
{
	return SessionCookieValue;
}

static FString FEL_BuildBasicAuthHeader(const FString& Id, const FString& Secret)
{
	const FString Pair = FString::Printf(TEXT("%s:%s"), *Id, *Secret);
	FTCHARToUTF8 Utf8(*Pair);
	TArray<uint8> Bytes;
	Bytes.Append(reinterpret_cast<const uint8*>(Utf8.Get()), Utf8.Length());
	return FString::Printf(TEXT("Basic %s"), *FBase64::Encode(Bytes));
}

static FString FEL_ExtractDmsessCookie(const FString& SetCookieHeader)
{
	if (SetCookieHeader.IsEmpty())
	{
		return FString();
	}
	int32 Start = SetCookieHeader.Find(TEXT("dmsess="), ESearchCase::CaseSensitive);
	if (Start == INDEX_NONE)
	{
		return SetCookieHeader;
	}
	int32 Semi = SetCookieHeader.Find(TEXT(";"), ESearchCase::CaseSensitive, ESearchDir::FromStart, Start);
	if (Semi == INDEX_NONE)
	{
		return SetCookieHeader.Mid(Start);
	}
	return SetCookieHeader.Mid(Start, Semi - Start);
}

void UFELDeepMotionSessionSubsystem::RequestSessionAuth()
{
	SessionCookieValue.Reset();
	if (ClientId.IsEmpty() || ClientSecret.IsEmpty())
	{
		RefreshCredentialsFromEnvironment();
	}
	if (ClientId.IsEmpty() || ClientSecret.IsEmpty())
	{
		OnSessionAuthComplete.Broadcast(false);
		return;
	}

	FHttpModule& Http = FHttpModule::Get();
	TSharedRef<IHttpRequest, ESPMode::ThreadSafe> Req = Http.CreateRequest();
	const FString Url = ApiHost.EndsWith(TEXT("/")) ? (ApiHost + TEXT("session/auth")) : (ApiHost + TEXT("/session/auth"));
	Req->SetURL(Url);
	Req->SetVerb(TEXT("GET"));
	Req->SetHeader(TEXT("Authorization"), FEL_BuildBasicAuthHeader(ClientId, ClientSecret));
	Req->OnProcessRequestComplete().BindUObject(this, &UFELDeepMotionSessionSubsystem::OnAuthResponse);
	Req->ProcessRequest();
}

void UFELDeepMotionSessionSubsystem::OnAuthResponse(FHttpRequestPtr Request, FHttpResponsePtr Response, bool bConnectedSuccessfully)
{
	if (!bConnectedSuccessfully || !Response.IsValid())
	{
		OnSessionAuthComplete.Broadcast(false);
		return;
	}
	const int32 Code = Response->GetResponseCode();
	if (Code < 200 || Code >= 300)
	{
		OnSessionAuthComplete.Broadcast(false);
		return;
	}
	const FString SetCookie = Response->GetHeader(TEXT("Set-Cookie"));
	SessionCookieValue = FEL_ExtractDmsessCookie(SetCookie);
	OnSessionAuthComplete.Broadcast(!SessionCookieValue.IsEmpty());
}
