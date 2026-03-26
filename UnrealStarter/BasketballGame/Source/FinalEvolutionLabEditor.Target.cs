// Copyright (c) Final Evolution Lab.

using UnrealBuildTool;
using System.Collections.Generic;

public class FinalEvolutionLabEditorTarget : TargetRules
{
	public FinalEvolutionLabEditorTarget(TargetInfo Target) : base(Target)
	{
		Type = TargetType.Editor;
		DefaultBuildSettings = BuildSettingsVersion.V6;
		IncludeOrderVersion = EngineIncludeOrderVersion.Unreal5_7;
		ExtraModuleNames.AddRange(new string[] { "FinalEvolutionLab" });
	}
}
