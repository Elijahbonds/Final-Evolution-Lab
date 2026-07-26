// Copy into your game's Source/FinalEvolutionLab/FinalEvolutionLab.Build.cs (or merge dependencies).

using UnrealBuildTool;

public class FinalEvolutionLab : ModuleRules
{
	public FinalEvolutionLab(ReadOnlyTargetRules Target) : base(Target)
	{
		PCHUsage = PCHUsageMode.UseExplicitOrSharedPCHs;

		PublicDependencyModuleNames.AddRange(new string[]
		{
			"Core",
			"CoreUObject",
			"Engine",
		});

		PrivateDependencyModuleNames.AddRange(new string[]
		{
			"Json",
			"RHI",
			"RenderCore",
			"WebSockets",
			"Sockets",
		});

		// iOS-only overlay (WKWebView) lives behind PLATFORM_IOS.
		if (Target.Platform == UnrealTargetPlatform.IOS)
		{
			PrivateDependencyModuleNames.AddRange(new string[]
			{
				"WebKit",
				"MetalRHI",
			});
		}
	}
}
