// Copyright (c) Final Evolution Lab.

#include "UFELBrainBrawlAcademySubsystem.h"
#include "HAL/PlatformFilemanager.h"
#include "Misc/FileHelper.h"
#include "Misc/Paths.h"
#include "Dom/JsonObject.h"
#include "Serialization/JsonReader.h"
#include "Serialization/JsonSerializer.h"
#include "Serialization/JsonWriter.h"

namespace
{
	static FString BrainBrawlProgressFilePath()
	{
		return FPaths::ProjectSavedDir() / TEXT("FEL/brain_brawl_academy_progress.json");
	}

	static FString BrainBrawlCurriculumFilePath()
	{
		return FPaths::ConvertRelativePathToFull(FPaths::ProjectContentDir() / TEXT("FEL/Config/BrainBrawlCurriculum.json"));
	}

	static void EnsureFELSavedDir()
	{
		const FString Dir = FPaths::ProjectSavedDir() / TEXT("FEL");
		IPlatformFile& PF = FPlatformFileManager::Get().GetPlatformFile();
		if (!PF.DirectoryExists(*Dir))
		{
			PF.CreateDirectoryTree(*Dir);
		}
	}
}

void UFELBrainBrawlAcademySubsystem::Initialize(FSubsystemCollectionBase& Collection)
{
	Super::Initialize(Collection);
	LoadCurriculumFromDisk();
	LoadProgressFromDisk();
}

void UFELBrainBrawlAcademySubsystem::LoadCurriculumFromDisk()
{
	PathCatalog.Reset();
	MasterQuestionBank.Reset();

	FString JsonStr;
	const FString Path = BrainBrawlCurriculumFilePath();
	if (!FPaths::FileExists(Path) || !FFileHelper::LoadFileToString(JsonStr, *Path))
	{
		LoadEmbeddedFallbackCurriculum();
		return;
	}

	TSharedPtr<FJsonObject> Root;
	const TSharedRef<TJsonReader<>> Reader = TJsonReaderFactory<>::Create(JsonStr);
	if (!FJsonSerializer::Deserialize(Reader, Root) || !Root.IsValid())
	{
		LoadEmbeddedFallbackCurriculum();
		return;
	}

	const TArray<TSharedPtr<FJsonValue>>* PathsJson = nullptr;
	if (Root->TryGetArrayField(TEXT("paths"), PathsJson) && PathsJson)
	{
		for (const TSharedPtr<FJsonValue>& V : *PathsJson)
		{
			const TSharedPtr<FJsonObject>* Obj = nullptr;
			if (!V.IsValid() || !V->TryGetObject(Obj) || !Obj->IsValid())
			{
				continue;
			}
			FFELBrainBrawlPathDef P;
			(*Obj)->TryGetStringField(TEXT("id"), P.Id);
			(*Obj)->TryGetStringField(TEXT("title"), P.Title);
			(*Obj)->TryGetNumberField(TEXT("difficulty01"), P.Difficulty01);
			P.Difficulty01 = FMath::Clamp(P.Difficulty01, 0.f, 1.f);
			const TArray<TSharedPtr<FJsonValue>>* Kw = nullptr;
			if ((*Obj)->TryGetArrayField(TEXT("interestKeywords"), Kw) && Kw)
			{
				for (const TSharedPtr<FJsonValue>& K : *Kw)
				{
					const FString S = K->AsString().TrimStartAndEnd().ToLower();
					if (!S.IsEmpty())
					{
						P.InterestKeywords.Add(S);
					}
				}
			}
			if (!P.Id.IsEmpty())
			{
				PathCatalog.Add(P);
			}
		}
	}

	const TArray<TSharedPtr<FJsonValue>>* QJson = nullptr;
	if (Root->TryGetArrayField(TEXT("questions"), QJson) && QJson)
	{
		for (const TSharedPtr<FJsonValue>& V : *QJson)
		{
			const TSharedPtr<FJsonObject>* Obj = nullptr;
			if (!V.IsValid() || !V->TryGetObject(Obj) || !Obj->IsValid())
			{
				continue;
			}
			FFELNeuroQuizItem Item;
			(*Obj)->TryGetStringField(TEXT("question"), Item.Question);
			const TArray<TSharedPtr<FJsonValue>>* AnsArr = nullptr;
			if ((*Obj)->TryGetArrayField(TEXT("answers"), AnsArr) && AnsArr)
			{
				for (const TSharedPtr<FJsonValue>& A : *AnsArr)
				{
					Item.Answers.Add(A->AsString());
				}
			}
			double CI = 0.0;
			(void)(*Obj)->TryGetNumberField(TEXT("correctIndex"), CI);
			Item.CorrectIndex = FMath::Clamp(static_cast<int32>(CI), 0, FMath::Max(0, Item.Answers.Num() - 1));
			FString DomStr;
			if ((*Obj)->TryGetStringField(TEXT("domain"), DomStr))
			{
				Item.Domain = FEL_ParseBrainBrawlDomain(DomStr);
			}
			const TArray<TSharedPtr<FJsonValue>>* PArr = nullptr;
			if ((*Obj)->TryGetArrayField(TEXT("pathIds"), PArr) && PArr)
			{
				for (const TSharedPtr<FJsonValue>& PV : *PArr)
				{
					const FString Id = PV->AsString().TrimStartAndEnd().ToLower();
					if (!Id.IsEmpty())
					{
						Item.PathIds.Add(Id);
					}
				}
			}
			if (Item.PathIds.Num() > 0)
			{
				Item.SourcePathId = Item.PathIds[0];
			}
			if (!Item.Question.IsEmpty() && Item.Answers.Num() > 0)
			{
				MasterQuestionBank.Add(Item);
			}
		}
	}

	if (PathCatalog.Num() == 0 || MasterQuestionBank.Num() == 0)
	{
		LoadEmbeddedFallbackCurriculum();
	}
}

void UFELBrainBrawlAcademySubsystem::LoadEmbeddedFallbackCurriculum()
{
	PathCatalog.Reset();
	MasterQuestionBank.Reset();

	FFELBrainBrawlPathDef Core;
	Core.Id = TEXT("core");
	Core.Title = TEXT("Core Neuro Kinesis");
	Core.InterestKeywords = {TEXT("core"), TEXT("foundation"), TEXT("brain"), TEXT("body")};
	Core.Difficulty01 = 0.45f;
	PathCatalog.Add(Core);

	auto AddQ = [&](const FString& Qs, TArray<FString>&& Ans, int32 Correct, EFELBrainBrawlCurriculumDomain D, const TArray<FString>& Pids)
	{
		FFELNeuroQuizItem Q;
		Q.Question = Qs;
		Q.Answers = MoveTemp(Ans);
		Q.CorrectIndex = Correct;
		Q.Domain = D;
		Q.PathIds = Pids;
		if (Q.PathIds.Num() > 0)
		{
			Q.SourcePathId = Q.PathIds[0];
		}
		MasterQuestionBank.Add(Q);
	};

	AddQ(
		TEXT("Which structure is most associated with procedural motor learning for repeated jump timing?"),
		{TEXT("Cerebellum"), TEXT("Occipital lobe"), TEXT("Broca's area"), TEXT("Medulla only")},
		0,
		EFELBrainBrawlCurriculumDomain::Analyze,
		{TEXT("core")});
	AddQ(
		TEXT("In sprint biomechanics, increased anterior pelvic tilt during acceleration often couples with:"),
		{TEXT("Lumbar hyperextension strategy"), TEXT("Ankle dorsiflexion only"), TEXT("Pure knee flexion dominance"), TEXT("Shoulder abduction drive")},
		0,
		EFELBrainBrawlCurriculumDomain::Analyze,
		{TEXT("core")});
	AddQ(
		TEXT("Rate of force development (RFD) is most sensitive to training that emphasizes:"),
		{TEXT("High-velocity intent and short ground contact"), TEXT("Only long-duration aerobic volume"), TEXT("Static stretching only"), TEXT("Passive ice immersion")},
		0,
		EFELBrainBrawlCurriculumDomain::Compute,
		{TEXT("core")});
	AddQ(
		TEXT("The stretch-shortening cycle (SSC) primarily exploits:"),
		{TEXT("Elastic energy storage and reflex potentiation"), TEXT("Pure isometric hold"), TEXT("Frictionless sliding only"), TEXT("Visual tracking alone")},
		0,
		EFELBrainBrawlCurriculumDomain::Identify,
		{TEXT("core")});
}

void UFELBrainBrawlAcademySubsystem::LoadProgressFromDisk()
{
	DomainProgress.Reset();
	const FString P = BrainBrawlProgressFilePath();
	if (!FPaths::FileExists(P))
	{
		return;
	}
	FString JsonStr;
	if (!FFileHelper::LoadFileToString(JsonStr, *P))
	{
		return;
	}
	TSharedPtr<FJsonObject> Root;
	const TSharedRef<TJsonReader<>> Reader = TJsonReaderFactory<>::Create(JsonStr);
	if (!FJsonSerializer::Deserialize(Reader, Root) || !Root.IsValid())
	{
		return;
	}
	const TArray<TSharedPtr<FJsonValue>>* Arr = nullptr;
	if (!Root->TryGetArrayField(TEXT("domainStats"), Arr) || !Arr)
	{
		return;
	}
	for (const TSharedPtr<FJsonValue>& V : *Arr)
	{
		const TSharedPtr<FJsonObject>* Obj = nullptr;
		if (!V.IsValid() || !V->TryGetObject(Obj) || !Obj->IsValid())
		{
			continue;
		}
		FFELBrainBrawlDomainProgress DP;
		FString Ds;
		if ((*Obj)->TryGetStringField(TEXT("domain"), Ds))
		{
			DP.Domain = FEL_ParseBrainBrawlDomain(Ds);
		}
		double A = 0.0, C = 0.0;
		(void)(*Obj)->TryGetNumberField(TEXT("attempts"), A);
		(void)(*Obj)->TryGetNumberField(TEXT("correct"), C);
		DP.Attempts = static_cast<int32>(A);
		DP.Correct = static_cast<int32>(C);
		DomainProgress.Add(DP);
	}
}

void UFELBrainBrawlAcademySubsystem::SaveProgressToDisk() const
{
	EnsureFELSavedDir();
	TSharedPtr<FJsonObject> Root = MakeShared<FJsonObject>();
	TArray<TSharedPtr<FJsonValue>> Arr;
	for (const FFELBrainBrawlDomainProgress& DP : DomainProgress)
	{
		TSharedPtr<FJsonObject> O = MakeShared<FJsonObject>();
		switch (DP.Domain)
		{
		case EFELBrainBrawlCurriculumDomain::Compute:
			O->SetStringField(TEXT("domain"), TEXT("compute"));
			break;
		case EFELBrainBrawlCurriculumDomain::Identify:
			O->SetStringField(TEXT("domain"), TEXT("identify"));
			break;
		case EFELBrainBrawlCurriculumDomain::Memorize:
			O->SetStringField(TEXT("domain"), TEXT("memorize"));
			break;
		case EFELBrainBrawlCurriculumDomain::Visualize:
			O->SetStringField(TEXT("domain"), TEXT("visualize"));
			break;
		default:
			O->SetStringField(TEXT("domain"), TEXT("analyze"));
			break;
		}
		O->SetNumberField(TEXT("attempts"), static_cast<double>(DP.Attempts));
		O->SetNumberField(TEXT("correct"), static_cast<double>(DP.Correct));
		Arr.Add(MakeShared<FJsonValueObject>(O));
	}
	Root->SetArrayField(TEXT("domainStats"), Arr);
	Root->SetStringField(TEXT("lastLocalPathId"), LocalPathId);
	Root->SetStringField(TEXT("lastOpponentPathId"), OpponentPathId);

	FString OutStr;
	const TSharedRef<TJsonWriter<TCHAR, TCondensedJsonPrintPolicy<TCHAR>>> Writer =
		TJsonWriterFactory<TCHAR, TCondensedJsonPrintPolicy<TCHAR>>::Create(&OutStr);
	if (FJsonSerializer::Serialize(Root.ToSharedRef(), Writer))
	{
		(void)FFileHelper::SaveStringToFile(OutStr, *BrainBrawlProgressFilePath());
	}
}

int32 UFELBrainBrawlAcademySubsystem::FindPathIndexById(const FString& Id) const
{
	const FString L = Id.TrimStartAndEnd().ToLower();
	for (int32 i = 0; i < PathCatalog.Num(); ++i)
	{
		if (PathCatalog[i].Id.Equals(L, ESearchCase::IgnoreCase))
		{
			return i;
		}
	}
	return INDEX_NONE;
}

FString UFELBrainBrawlAcademySubsystem::PickOpponentPathId(const FString& AvoidId) const
{
	TArray<int32> Cand;
	const FString AL = AvoidId.TrimStartAndEnd().ToLower();
	for (int32 i = 0; i < PathCatalog.Num(); ++i)
	{
		if (!PathCatalog[i].Id.Equals(AL, ESearchCase::IgnoreCase))
		{
			Cand.Add(i);
		}
	}
	if (Cand.Num() == 0)
	{
		return TEXT("core");
	}
	const int32 Pick = Cand[FMath::RandRange(0, Cand.Num() - 1)];
	return PathCatalog[Pick].Id;
}

int32 UFELBrainBrawlAcademySubsystem::ScorePromptAgainstPath(const FString& PromptLower, const FFELBrainBrawlPathDef& Path) const
{
	int32 Score = 0;
	for (const FString& Kw : Path.InterestKeywords)
	{
		if (Kw.Len() > 1 && PromptLower.Contains(Kw))
		{
			Score += 3;
		}
	}
	if (Path.Id.Len() > 2 && PromptLower.Contains(Path.Id.Replace(TEXT("_"), TEXT(" "))))
	{
		Score += 2;
	}
	return Score;
}

FString UFELBrainBrawlAcademySubsystem::ResolveGuidedPathIdFromInterestPrompt(const FString& InterestPrompt) const
{
	if (PathCatalog.Num() == 0)
	{
		return TEXT("core");
	}
	const FString Trimmed = InterestPrompt.TrimStartAndEnd();
	if (Trimmed.IsEmpty())
	{
		return TEXT("core");
	}
	const FString L = Trimmed.ToLower();
	int32 BestScore = 0;
	FString BestId = TEXT("core");
	for (const FFELBrainBrawlPathDef& P : PathCatalog)
	{
		const int32 S = ScorePromptAgainstPath(L, P);
		if (S > BestScore)
		{
			BestScore = S;
			BestId = P.Id;
		}
	}
	return BestId;
}

void UFELBrainBrawlAcademySubsystem::RebuildActiveQuestionBank()
{
	ActiveLocalQuestionBank.Reset();
	TSet<FString> Seen;
	auto AddUnique = [&Seen, this](const FFELNeuroQuizItem& Q)
	{
		if (Seen.Contains(Q.Question))
		{
			return;
		}
		Seen.Add(Q.Question);
		ActiveLocalQuestionBank.Add(Q);
	};

	const FString LocalLower = LocalPathId.TrimStartAndEnd().ToLower();
	for (const FFELNeuroQuizItem& Q : MasterQuestionBank)
	{
		if (Q.PathIds.Contains(TEXT("core")))
		{
			AddUnique(Q);
		}
	}
	for (const FFELNeuroQuizItem& Q : MasterQuestionBank)
	{
		if (LocalLower.Len() > 0 && LocalLower != TEXT("core") && Q.PathIds.Contains(LocalLower))
		{
			AddUnique(Q);
		}
	}

	if (ActiveLocalQuestionBank.Num() == 0)
	{
		if (MasterQuestionBank.Num() == 0)
		{
			LoadEmbeddedFallbackCurriculum();
		}
		for (const FFELNeuroQuizItem& Q : MasterQuestionBank)
		{
			if (Q.PathIds.Contains(TEXT("core")))
			{
				AddUnique(Q);
			}
		}
	}
}

void UFELBrainBrawlAcademySubsystem::BeginAcademyDuel(
	float RoundSeconds,
	const FString& InterestPrompt,
	const FString& OpponentPathIdOrEmpty)
{
	bDuelFinalized = false;
	bDuelActive = true;
	LocalCorrectCount = 0;
	LocalQuestionsAnswered = 0;
	OpponentCorrectCount = 0;
	OpponentQuestionsResolved = 0;
	OpponentQuestionAccumulator = 0.f;
	OpponentNextQuestionInterval = FMath::FRandRange(7.f, 13.f);

	LocalPathId = ResolveGuidedPathIdFromInterestPrompt(InterestPrompt);
	const int32 OppIdx = FindPathIndexById(OpponentPathIdOrEmpty);
	if (OppIdx != INDEX_NONE)
	{
		OpponentPathId = PathCatalog[OppIdx].Id;
	}
	else
	{
		OpponentPathId = PickOpponentPathId(LocalPathId);
	}

	const int32 Li = FindPathIndexById(LocalPathId);
	LocalPathTitle = (Li != INDEX_NONE) ? PathCatalog[Li].Title : TEXT("Core curriculum");

	const int32 Oi = FindPathIndexById(OpponentPathId);
	OpponentPathTitle = (Oi != INDEX_NONE) ? PathCatalog[Oi].Title : TEXT("Friend path");
	OpponentDifficulty01 = (Oi != INDEX_NONE) ? PathCatalog[Oi].Difficulty01 : 0.5f;

	RebuildActiveQuestionBank();

	RemainingDuelSeconds = FMath::Max(15.f, RoundSeconds);
	ConfiguredRoundSeconds = FMath::RoundToInt(RemainingDuelSeconds);
}

void UFELBrainBrawlAcademySubsystem::TickDuel(float DeltaSeconds)
{
	if (!bDuelActive || bDuelFinalized)
	{
		return;
	}

	const float Dt = FMath::Clamp(DeltaSeconds, 0.f, 0.5f);
	RemainingDuelSeconds = FMath::Max(0.f, RemainingDuelSeconds - Dt);

	if (RemainingDuelSeconds <= 0.f)
	{
		bDuelActive = false;
		return;
	}

	OpponentQuestionAccumulator += Dt;
	while (OpponentQuestionAccumulator >= OpponentNextQuestionInterval && RemainingDuelSeconds > 0.f)
	{
		OpponentQuestionAccumulator -= OpponentNextQuestionInterval;
		OpponentNextQuestionInterval = FMath::FRandRange(7.f, 14.f);
		OpponentQuestionsResolved++;
		const float P = FMath::Clamp(0.28f + OpponentDifficulty01 * 0.5f, 0.2f, 0.82f);
		if (FMath::FRand() < P)
		{
			OpponentCorrectCount++;
		}
	}
}

void UFELBrainBrawlAcademySubsystem::RecordLocalAnswer(const FFELNeuroQuizItem& Item, bool bCorrect)
{
	LocalQuestionsAnswered++;
	if (bCorrect)
	{
		LocalCorrectCount++;
	}

	FFELBrainBrawlDomainProgress* Found = nullptr;
	for (FFELBrainBrawlDomainProgress& DP : DomainProgress)
	{
		if (DP.Domain == Item.Domain)
		{
			Found = &DP;
			break;
		}
	}
	if (!Found)
	{
		FFELBrainBrawlDomainProgress NewP;
		NewP.Domain = Item.Domain;
		DomainProgress.Add(NewP);
		Found = &DomainProgress.Last();
	}
	Found->Attempts++;
	if (bCorrect)
	{
		Found->Correct++;
	}
}

void UFELBrainBrawlAcademySubsystem::FinalizeDuelAndPersistProgress()
{
	if (bDuelFinalized)
	{
		return;
	}
	bDuelFinalized = true;
	bDuelActive = false;
	SaveProgressToDisk();
}
