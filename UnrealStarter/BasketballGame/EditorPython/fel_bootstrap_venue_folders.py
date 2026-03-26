# Copyright (c) Final Evolution Lab.
# Unreal Editor: Output Log -> py "<path-to-this-file>"
# Creates Content folders for Luma/Venice court, Dojo art, and props (safe if they already exist).

import unreal

FOLDERS = [
    "/Game/FEL/Venues/VeniceBeach",
    "/Game/FEL/Venues/Dojo",
    "/Game/FEL/Venues/SoccerStadium",
    "/Game/FEL/Venues/BaseballPark",
    "/Game/FEL/Venues/Gridiron",
    "/Game/FEL/Venues/Links",
    "/Game/FEL/Venues/TennisCourt",
    "/Game/FEL/Venues/SandCourt",
    "/Game/FEL/Venues/TrainingFloor",
    "/Game/FEL/Venues/NeuroArena",
    "/Game/FEL/Environment/Venice",
    "/Game/FEL/Environment/Luma",
    "/Game/FEL/Environment/Dojo",
    "/Game/FEL/Environment/Soccer",
    "/Game/FEL/Environment/Props",
    "/Game/FEL/Environment/Shared",
    "/Game/FEL/Audio/Ambience",
    "/Game/FEL/StreamingAssets/Meshy",
]


def main():
    lib = unreal.EditorAssetLibrary
    for p in FOLDERS:
        if not lib.does_directory_exist(p):
            lib.make_directory(p)
            unreal.log("FEL: created " + p)
        else:
            unreal.log("FEL: exists " + p)
    unreal.log("FEL: venue bootstrap done — import Luma mesh into Environment/Luma or Venice, then save VeniceBeach + Dojo maps.")


main()
