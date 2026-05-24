#!/usr/bin/env python3
import os
import sys
import json
import shutil
import re

def migrate(project_dir):
    print(f"=== Starting FEL Migration to: {project_dir} ===")
    
    # 1. Paths
    repo_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    source_integration = os.path.join(repo_root, "UnrealIntegration", "Source", "FinalEvolutionLab")
    dest_source = os.path.join(project_dir, "Source", "FinalEvolutionLab")
    
    # 2. Copy C++ Source files
    print(f"Copying C++ Source Module from {source_integration} to {dest_source}...")
    if os.path.exists(dest_source):
        shutil.rmtree(dest_source)
    shutil.copytree(source_integration, dest_source)
    print("OK: Copied C++ source files")
    
    # 3. Update uproject
    uproject_file = None
    for f in os.listdir(project_dir):
        if f.endswith(".uproject"):
            uproject_file = os.path.join(project_dir, f)
            break
            
    if not uproject_file:
        print("ERROR: No .uproject file found in target directory!")
        sys.exit(1)
        
    print(f"Updating uproject file: {uproject_file}...")
    with open(uproject_file, 'r') as f:
        uproj_data = json.load(f)
        
    modules = uproj_data.setdefault("Modules", [])
    if not any(m.get("Name") == "FinalEvolutionLab" for m in modules):
        modules.append({
            "Name": "FinalEvolutionLab",
            "Type": "Runtime",
            "LoadingPhase": "Default"
        })
        with open(uproject_file, 'w') as f:
            json.dump(uproj_data, f, indent=4)
        print("OK: Registered FinalEvolutionLab module in .uproject")
    else:
        print("FinalEvolutionLab module already registered in .uproject")
        
    # 4. Update Target.cs files
    targets = [
        os.path.join(project_dir, "Source", "MyProject.Target.cs"),
        os.path.join(project_dir, "Source", "MyProjectEditor.Target.cs")
    ]
    for target in targets:
        if os.path.exists(target):
            print(f"Updating Target file: {target}...")
            with open(target, 'r') as f:
                content = f.read()
            if "FinalEvolutionLab" not in content:
                # Add FinalEvolutionLab to ExtraModuleNames
                # Match any ExtraModuleNames.AddRange( new string[] { ... } );
                pattern = r'(ExtraModuleNames\.AddRange\(\s*new\s+string\[\]\s*\{\s*)"MyProject"(\s*\}\s*\)\s*;)'
                if re.search(pattern, content):
                    content = re.sub(pattern, r'\1"MyProject", "FinalEvolutionLab"\2', content)
                else:
                    # Fallback string replace
                    content = content.replace('"MyProject"', '"MyProject", "FinalEvolutionLab"')
                with open(target, 'w') as f:
                    f.write(content)
                print(f"OK: Added FinalEvolutionLab to target: {target}")
            else:
                print(f"FinalEvolutionLab already registered in target: {target}")
        else:
            print(f"WARN: Target file not found: {target}")
            
    # 5. Copy Venue Registry JSON
    src_registry = os.path.join(repo_root, "UnrealStarter", "BasketballGame", "Config", "FEL_VenueRegistry.production.json")
    dest_registry = os.path.join(project_dir, "Config", "FEL_VenueRegistry.production.json")
    print(f"Copying Venue Registry to {dest_registry}...")
    shutil.copy2(src_registry, dest_registry)
    print("OK: Copied FEL_VenueRegistry.production.json")
    
    # 6. Append Snippets to DefaultEngine.ini
    engine_ini = os.path.join(project_dir, "Config", "DefaultEngine.ini")
    print(f"Merging Snippets into {engine_ini}...")
    with open(engine_ini, 'r') as f:
        engine_content = f.read()
        
    # Read iOS snippet
    ios_snippet_path = os.path.join(repo_root, "UnrealIntegration", "Config", "DefaultEngine.FEL_iOS_URL_scheme.snippet.ini")
    with open(ios_snippet_path, 'r') as f:
        ios_snippet = f.read()
        
    # Read Pixel Streaming snippet
    ps_snippet_path = os.path.join(repo_root, "UnrealStarter", "BasketballGame", "Config", "DefaultEngine.pixelstreaming2.snippet.ini")
    with open(ps_snippet_path, 'r') as f:
        ps_snippet = f.read()
        
    appended_any = False
    if "[/Script/IOSRuntimeSettings.IOSRuntimeSettings]" not in engine_content:
        engine_content += "\n\n" + ios_snippet
        appended_any = True
        print("OK: Appended iOS URL Scheme config to DefaultEngine.ini")
    else:
        print("iOS settings already exist in DefaultEngine.ini, skipping")
        
    if "PixelStreaming2.AutoStartStream" not in engine_content:
        engine_content += "\n\n" + ps_snippet
        appended_any = True
        print("OK: Appended Pixel Streaming settings to DefaultEngine.ini")
    else:
        print("Pixel Streaming settings already exist in DefaultEngine.ini, skipping")
        
    if appended_any:
        with open(engine_ini, 'w') as f:
            f.write(engine_content)
            
    # 7. Run prep scripts using subprocess with environment variables
    print("Running prep scripts...")
    os.environ["PROJECT_DIR"] = project_dir
    os.environ["EMERGENT_MERGE_SNIPPET"] = "1"
    
    # Run prepare_fel_emergent.sh
    emergent_script = os.path.join(repo_root, "prepare_fel_emergent.sh")
    print(f"Executing: PROJECT_DIR={project_dir} {emergent_script}")
    rc = os.system(f'"{emergent_script}"')
    if rc != 0:
        print("ERROR: prepare_fel_emergent.sh failed!")
        sys.exit(1)
        
    # Run prepare_fel_full_ship.sh
    ship_script = os.path.join(repo_root, "prepare_fel_full_ship.sh")
    print(f"Executing: PROJECT_DIR={project_dir} {ship_script}")
    rc = os.system(f'"{ship_script}"')
    if rc != 0:
        print("ERROR: prepare_fel_full_ship.sh failed!")
        sys.exit(1)
        
    print("=== Migration completed successfully! ===")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        proj_dir = "/Users/elijahbonds/Documents/Unreal Projects/MyProject"
    else:
        proj_dir = sys.argv[1]
    migrate(proj_dir)
