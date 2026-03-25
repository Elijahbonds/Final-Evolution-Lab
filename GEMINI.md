# Add Gemini to Xcode (Final Evolution Lab)

Google Gemini is integrated via **GeminiService** for AI features (e.g. Photo-to-Shard meal analysis, future chat). No Swift Package is required; the app uses the Gemini REST API.

## 1. Get an API key

1. Open [Google AI Studio](https://aistudio.google.com/apikey).
2. Create or sign in with your Google account.
3. Click **Create API key** and copy the key.

## 2. Add the key in Xcode

**Option A – Info.plist (recommended for release)**  
1. In Xcode, select the **FinalEvolutionLab** target.  
2. Open the **Info** tab.  
3. Under **Custom iOS Target Properties**, click **+** and add:
   - **Key:** `GEMINI_API_KEY`  
   - **Type:** String  
   - **Value:** your API key (do not commit real keys; use a secrets scheme or xcconfig).

**Option B – Environment variable (for local dev)**  
1. In Xcode: **Product → Scheme → Edit Scheme**.  
2. Select **Run → Arguments**.  
3. Under **Environment Variables**, add:
   - **Name:** `GEMINI_API_KEY`  
   - **Value:** your API key  

**Option C – Code (dev only, do not commit)**  
In `FinalEvolutionLabApp.swift` or at first use:

```swift
Task { @MainActor in
    GeminiService.shared.configure(apiKey: "YOUR_KEY_HERE")
}
```

## 3. Use Gemini in the app

- **Text:** `let response = try await GeminiService.shared.generateContent(prompt: "Your prompt")`
- **Image (e.g. meal photo):** `let response = try await GeminiService.shared.generateContentWithImage(prompt: "Analyze this meal for protein and vegetables.", imageBase64: base64String)`

If the key is not set, calls throw `GeminiError.missingAPIKey` with a clear message. The Fuel tab’s “Scan meal” can be wired to the camera, then pass the image to `generateContentWithImage` and parse the response for shard rewards.

## 4. Architecture review bundle (AI Studio)

For a **single Markdown export** (Swift + Unreal C++ + Python + key docs) with a ready-to-paste **system instruction**, open the generated file at the repo root:

- **`AI_STUDIO_FEL_ARCHITECTURE_BUNDLE.md`** — regenerate after code changes with:

  `python3 scripts/generate_ai_studio_bundle.py`

- **`DOCS/INTEGRATION_RUNTIME.md`** — Supabase, Unity Meshy streaming, Unreal Meshy/Luma import paths (3D load checklist).
