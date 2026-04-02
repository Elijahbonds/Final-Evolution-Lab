# Magic Reveal Videos

Venue reveal videos for the Final Evolution Lab venues.
These can be used as splash/reveal animations in the app.

## Videos

| Video | Venue | Duration |
|-------|-------|----------|
| `Venice_Beach_Court_magic_reveal.mp4` | Venice Beach Basketball Court | ~10s |
| `Venice_Ball_Shop_magic_reveal.mp4` | Venice Ball Shop | ~10s |
| `Muscle_beach_gym_magic_reveal.mp4` | Muscle Beach Gym | ~10s |
| `Muscle_beach_stage_magic_reveal.mp4` | Muscle Beach Stage | ~10s |
| `Venice_beach_tennis_courts_magic_reveal.mp4` | Venice Beach Tennis Courts | ~15s |
| `Venice_Beach_Black_Top_magic_reveal.mp4` | Venice Beach Black Top Court | ~10s |
| `Hoopbus_magic_reveal.mp4` | Hoopbus Mobile Court | ~10s |

## Usage in Swift App

These can be played using `VideoPlayerView.swift` or `AVPlayer`:

```swift
import AVKit

let videoURL = Bundle.main.url(
    forResource: "Venice_Beach_Court_magic_reveal",
    withExtension: "mp4"
)
let player = AVPlayer(url: videoURL!)
```

## Adding to Xcode Project

1. Drag the `.mp4` files into the Xcode project navigator
2. Ensure they are added to the **FinalEvolutionLab** target
3. They will be included in the app bundle
