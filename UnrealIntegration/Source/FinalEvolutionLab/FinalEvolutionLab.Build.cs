// Copyright Epic Games, Inc. All Rights Reserved.

using UnrealBuildTool;

public class FinalEvolutionLab : ModuleRules
{
	public FinalEvolutionLab(ReadOnlyTargetRules Target) : base(Target)
	{
		PCHUsage = PCHUsageMode.UseExplicitOrSharedPCHs;
	
		PublicDependencyModuleNames.AddRange(new string[] {
			"Core", "CoreUObject", "Engine", "InputCore", "PhysicsCore", "Json", "JsonUtilities",
			"Niagara",
			"UMG",
			"Slate",
			"SlateCore",
			"CommonUI",
			"EnhancedInput",
			"LiveLink",
			"LiveLinkComponents",
			"LiveLinkInterface",
			"LiveLinkAnimationCore",
		});

		PrivateDependencyModuleNames.AddRange(new string[] {
			"WebSockets",
			"SQLiteCore",
			"Sockets",
			"WebBrowser",
			"WebBrowserWidget",
		});

		if (Target.Platform == UnrealTargetPlatform.IOS)
		{
			PublicFrameworks.AddRange(new string[] { "CoreMotion", "AudioToolbox", "CoreImage", "WebKit" });
		}
	}
}
