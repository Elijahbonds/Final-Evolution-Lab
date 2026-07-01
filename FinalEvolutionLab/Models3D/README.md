# Models3D — Meshy.ai USDZ Assets

Drop your exported Meshy `.usdz` files here. The app loads them by name at runtime.

## Expected file names

| Meshy Share Link      | File to drop here                     | Used in                        |
|-----------------------|---------------------------------------|--------------------------------|
| meshy.ai/s/sm8Bi9     | `elijah_bonds.usdz`                   | CharacterBuilder · AvatarDemo  |
| meshy.ai/s/AW2mM7     | `amir_smith.usdz`                     | Basketball 3v3 (teammate)      |
| meshy.ai/s/J4Ldo6     | `venice_beach_hoop.usdz`             | Dunk Contest · Basketball 3v3  |
| meshy.ai/s/vsNQzK     | `basketball_court_set.usdz`          | AvatarDemo background          |
| meshy.ai/s/ev2MZQ     | `hoopbus_basketball.usdz`            | CharacterBuilder prop          |
| meshy.ai/s/pcPfoa     | `indoor_basketball_court.usdz`       | AvatarDemo alternate court     |
| meshy.ai/s/gbvJVm     | `soccer_stadium.usdz`                | Soccer game environment        |
| meshy.ai/s/FEZUHT     | `soccer_ball.usdz`                   | Soccer ball prop               |
| meshy.ai/s/QiHuT3     | `tennis_ball.usdz`                   | Tennis ball prop               |
| meshy.ai/s/QYupzy     | `tennis_racket.usdz`                 | Tennis game prop               |

## How to export from Meshy

1. Open the model on meshy.ai
2. Click **Download** → select **USDZ** format
3. Rename the file to match the table above
4. Drag it into Xcode under `FinalEvolutionLab/Models3D/` (make sure "Copy items if needed" is checked)
5. Build — the app will automatically detect and load the model

## Fallback behavior

If a `.usdz` file is NOT present, the app shows a high-quality canvas-drawn placeholder.
No code changes needed — just drop in the files.
