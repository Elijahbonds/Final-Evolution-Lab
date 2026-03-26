# Run inside Unreal: Window → Developer Tools → Output Log → `py "…/EditorPython/fel_seed_dunk_mocap_folders.py"`
# Creates Content folders for archetype + pro dunk imports (no montage assets — assign refs on the subsystem CDO).
import unreal

_ROOT = "/Game/FEL/Mocap/Dunkers"
_ARCHETYPES = (
	"Generic",
	"Windmill",
	"Tomahawk",
	"Eastbay",
	"BetweenTheLegs",
	"Spin360",
	"AlleyOop",
	"Reverse",
	"TwoHandPower",
	"Cradle",
	"FreeThrowApproach",
)
_PROS = ("ElijahBonds", "AmirSmith", "AdditionalPros")


def _ensure_dir(path: str) -> None:
	if not unreal.EditorAssetLibrary.does_directory_exist(path):
		unreal.EditorAssetLibrary.make_directory(path)


def main() -> None:
	_ensure_dir(_ROOT)
	for name in _ARCHETYPES:
		_ensure_dir(f"{_ROOT}/Archetypes/{name}")
	for name in _PROS:
		_ensure_dir(f"{_ROOT}/Pros/{name}")
	unreal.log("FEL: dunk mocap folder tree ready under /Game/FEL/Mocap/Dunkers — wire montages in UFELAcademyMocapCatalogSubsystem.")


main()
