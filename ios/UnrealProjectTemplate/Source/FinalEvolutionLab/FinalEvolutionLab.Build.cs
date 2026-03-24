using UnrealBuildTool;

public class FinalEvolutionLab : ModuleRules
{
    public FinalEvolutionLab(ReadOnlyTargetRules Target) : base(Target)
    {
        PCHUsage = PCHUsageMode.UseExplicitOrSharedPCHs;

        PublicDependencyModuleNames.AddRange(
            new[]
            {
                "Core",
                "CoreUObject",
                "Engine",
                "InputCore",
                "EnhancedInput",
                "UMG",
                "Json",
                "JsonUtilities"
            }
        );
    }
}
