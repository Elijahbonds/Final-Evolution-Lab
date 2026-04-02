"""Import magic reveal videos as UE5 MediaTexture assets.

Run in UE5 Editor: Edit > Editor Preferences > Python > execute
Or via commandlet: UE_CMD -run=pythonscript -script=this_file.py
"""
import unreal
import json
import os

# Video assets to import as Media Source
MAGIC_REVEAL_VIDEOS = [
    {'name': 'Venice_Beach_Court_magic_reveal', 'file': 'Venice_Beach_Court_magic_reveal.mp4', 'venue': 'venice_basketball'},
    {'name': 'Venice_Ball_Shop_magic_reveal', 'file': 'Venice_Ball_Shop_magic_reveal.mp4', 'venue': 'marketplace'},
    {'name': 'Muscle_beach_gym_magic_reveal', 'file': 'Muscle_beach_gym_magic_reveal.mp4', 'venue': 'training_gym'},
    {'name': 'Muscle_beach_stage_magic_reveal', 'file': 'Muscle_beach_stage_magic_reveal.mp4', 'venue': 'beach_tropical'},
    {'name': 'Venice_beach_tennis_courts_magic_reveal', 'file': 'Venice_beach_tennis_courts_magic_reveal.mp4', 'venue': 'tennis_court'},
    {'name': 'Venice_Beach_Black_Top_magic_reveal', 'file': 'Venice_Beach_Black_Top_magic_reveal.mp4', 'venue': 'rooftop_cityscape'},
    {'name': 'Hoopbus_magic_reveal', 'file': 'Hoopbus_magic_reveal.mp4', 'venue': 'classic_nba_arena'},
]

SOURCE_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), 'SourceVideos', 'MagicReveal')
DEST_PATH = '/Game/FEL/Media/MagicReveal'

def import_video_assets():
    asset_tools = unreal.AssetToolsHelpers.get_asset_tools()
    
    # Ensure destination directory exists
    if not unreal.EditorAssetLibrary.does_directory_exist(DEST_PATH):
        unreal.EditorAssetLibrary.make_directory(DEST_PATH)
    
    imported = 0
    for video in MAGIC_REVEAL_VIDEOS:
        source_file = os.path.join(SOURCE_DIR, video['file'])
        if not os.path.exists(source_file):
            unreal.log_warning(f"Video not found: {source_file}")
            continue
        
        # Create FileMediaSource
        factory = unreal.FileMediaSourceFactoryNew()
        media_source = asset_tools.create_asset(
            video['name'] + '_Source',
            DEST_PATH,
            unreal.FileMediaSource,
            factory
        )
        if media_source:
            media_source.set_editor_property('file_path', source_file)
            imported += 1
            unreal.log(f"Imported: {video['name']} -> {DEST_PATH}/{video['name']}_Source")
    
    unreal.log(f"Imported {imported}/{len(MAGIC_REVEAL_VIDEOS)} video assets")
    return imported

if __name__ == '__main__':
    import_video_assets()
