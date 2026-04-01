// Copyright (c) Final Evolution Lab.
// Copy into your Unreal game module as FinalEvolutionLab.Build.cs (merge PublicDependencyModuleNames with your existing list).
//
// UE_BUILD_SHIPPING: set automatically by Unreal for **Shipping** configuration only. Do **not** define it in Build.cs.
// Strip FELNeuroDebugHUD + dev UE_LOG with #if !UE_BUILD_SHIPPING in C++ (FELBasketballPlayerController, FELBasketballGameMode, UFELDemoManager).
//
// iOS / Metal: the engine targets Metal RHI on iPhone; Niagara + materials compile to MSF for Metal. ProMotion 120Hz is frame pacing + `Info.plist`
// (`CADisableMinimumFrameDurationOnPhone`); no extra shader flag is required for “hologram” materials beyond shipping a cooked iOS build.

using UnrealBuildTool;

public class FinalEvolutionLab : ModuleRules
{
	public FinalEvolutionLab(ReadOnlyTargetRules Target) : base(Target)
	{
		PCHUsage = PCHUsageMode.UseExplicitOrSharedPCHs;

		// Mac/iOS installed-engine builds: PLATFORM_PS5 is undefined; UE enables -Wundef on third-party code.
		if (Target.Platform == UnrealTargetPlatform.Mac || Target.Platform == UnrealTargetPlatform.IOS)
		{
			PublicDefinitions.Add("PLATFORM_PS5=0");
		}

		PublicDependencyModuleNames.AddRange(new string[]
		{
			"Core",
			"CoreUObject",
			"Engine",
			"InputCore",
			"EnhancedInput",
			"PhysicsCore",
			"Json",
			"JsonUtilities",
			"HTTP",
			"UMG",
			"Slate",
			"SlateCore",
			"Niagara",
			"RenderCore",
			"RHI",
			"MotionWarping",
			"AssetRegistry"
		});

		// Gold Master: optional project-specific flag when packaging Shipping (do not redefine UE_BUILD_SHIPPING).
		if (Target.Configuration == UnrealTargetConfiguration.Shipping)
		{
			PublicDefinitions.Add("FEL_PACKAGE_SHIPPING=1");
		}

		// iOS uses Metal by default; tag module for Metal-backed Niagara / post-process parity in audits.
		if (Target.Platform == UnrealTargetPlatform.IOS)
		{
			PublicDefinitions.Add("FEL_IOS_METAL_RHI=1");
		}

		// Universal Launch / Pixel Streaming (Web): enabled for streaming game modes to browser clients via Wilbur signalling.
		PublicDefinitions.Add("PIXEL_STREAMING_ENABLED=1");
	}
}
