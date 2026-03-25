# Video → Animation Pipeline (Instagram as Source)

Use **video-to-animation** tools to turn footage into 3D character animations. Use **Instagram** (Reels, posts) as the video source for movement reference—dunks, 90/90, wall pushes, sport clips—then run them through AI motion capture and export to Unreal or your game pipeline.

---

## 1. Recommended Tools (Video → 3D Animation)

| Tool | What it does | Export | Best for |
|------|----------------|--------|----------|
| **DeepMotion Animate 3D** | Video → 3D motion capture (browser). Markerless; up to 8 people; face & hands; foot locking; rotoscope pose editor. | FBX, BVH, GLB, MP4 | Game-ready FBX, retargeting to your rig. |
| **Plask** | Video → 3D animation in minutes. Markerless; motion blending; pose cleanup. | Unreal, Maya, Blender | Direct Unreal workflow. |
| **DIMO** (dimo3d.space) | AI motion capture platform; video to 3D animation. | Standard 3D formats | Alternative pipeline. |
| **Rokoko Video** | Browser video-to-mocap; retarget to Mixamo/UE. | FBX, etc. | If you use Rokoko stack. |

**Suggested primary:** **DeepMotion Animate 3D** (free tier, FBX/BVH/GLB) or **Plask** (Unreal/Maya/Blender export). Both work with smartphone or web-uploaded video—ideal for clips from Instagram.

---

## 2. Using Instagram as the Animation Source

**Idea:** Use Instagram **Reels** or **video posts** as reference footage: real dunks, 90/90 stretches, wall pushes, sport moves. Then convert that video to 3D animation and retarget to your Academy characters.

### Step 1: Get the video

- **Option A – Your own content:** Film yourself (or an athlete) doing the move; post as Reel or private; download via Instagram “Download” (your post) or screen record.
- **Option B – Public Reels (rights-aware):** Only use clips you have **rights** to (your account, licensed, or royalty-free). Download with a Reels downloader (e.g. save reel to camera roll) or use Instagram’s “Save” then export if available.
- **Tip:** Short clips (5–15 s), clear full-body view, good lighting, and minimal occlusion give the best results for motion capture.

### Step 2: Prepare the video

- **Format:** MP4 or MOV; 1080p is enough for most tools.
- **Framerate:** 24–30 fps is typical; match what your Unreal project uses (e.g. 30).
- **Content:** Single person in frame, full body visible, flat angle (avoid heavy perspective distortion) for best tracking.

### Step 3: Run through video-to-animation tool

1. Open **DeepMotion Animate 3D** (deepmotion.com/animate-3d) or **Plask** (plask.ai).
2. Upload the Instagram-sourced (or any) video.
3. Let the tool detect the person and generate 3D motion.
4. Use any **pose editor** / **foot lock** / **cleanup** options to fix sliding feet or jitter.
5. Export as **FBX** (or BVH/GLB if you prefer and your pipeline supports it).

### Step 4: Use in Unreal / Academy project

- Import the **FBX** into Unreal as a **Skeletal Mesh** or **Animation Sequence**.
- **Retarget** to your character skeleton (Arena Athlete, Dunker, Movement Snack character) if the rigs differ.
- Use **Control Rig** for 90/90 and Wall Push so feet stay IK-locked; you can drive it from the captured motion or blend with it.

---

## 3. Pipeline Summary

```
Instagram (Reels / video) → Download → Video file (MP4/MOV)
       → DeepMotion or Plask (video-to-mocap)
       → FBX / BVH / GLB
       → Unreal Engine: import, retarget to Academy character
       → Control Rig (optional): IK, foot lock for 90/90, Wall Push
```

---

## 4. What to Capture from Instagram (Examples)

| Movement | Use case | Instagram source idea |
|----------|----------|------------------------|
| Dunk / layup | Dunker character | Reels of dunk contests, pickup dunks (your own or licensed). |
| 90/90 seated | Movement snack | Short clip of 90/90 hip stretch; full body in frame. |
| Wall push (isometric) | NMS reset | Clip of split-stance wall push. |
| Run / sprint | Arena athlete | Running Reels, sport drills. |
| Jump / landing | Plyo, dunk prep | Jump and land clips, side or front view. |

---

## 5. Links

- **DeepMotion Animate 3D:** https://deepmotion.com/animate-3d  
- **Plask:** https://plask.ai  
- **DIMO:** https://dimo3d.space  
- **Rokoko Video:** https://rokoko.com/products/rokoko-video  

---

## 6. Legal / Rights

- Only use **your own** Instagram content or content you’re **licensed** to use when creating animations for the Academy.
- If you use someone else’s Reel, get permission or use only royalty-free / CC-licensed material. Do not redistribute the original Instagram video in your app without rights.

---

*Vertical Velocity Academy — video-to-animation pipeline using Instagram as source and AI mocap tools for Unreal.*
