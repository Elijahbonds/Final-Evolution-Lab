#!/usr/bin/env python3
"""Auto-generated Unreal Editor Python script — imports AI-generated assets."""
import unreal

asset_tools = unreal.AssetToolsHelpers.get_asset_tools()
import_tasks = []

if import_tasks:
    asset_tools.import_asset_tasks(import_tasks)
    unreal.log(f"Imported {len(import_tasks)} AI-generated assets")
else:
    unreal.log("No assets to import")