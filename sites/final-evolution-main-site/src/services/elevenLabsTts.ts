/**
 * ElevenLabs text-to-speech for Academy voiceover.
 *
 * Set `VITE_ELEVENLABS_API_KEY` + `VITE_ELEVENLABS_VOICE_ID` (Dashboard → Voices → voice ID).
 * For production, prefer a server-side proxy so the API key never ships in the browser bundle.
 */

export function elevenLabsConfigured(): boolean {
  const k = import.meta.env.VITE_ELEVENLABS_API_KEY?.trim();
  const v = import.meta.env.VITE_ELEVENLABS_VOICE_ID?.trim();
  return Boolean(k && v);
}

/**
 * Synthesizes speech and plays it. Resolves when playback ends or is stopped.
 * Returns the `HTMLAudioElement` so callers can pause/stop.
 */
export async function playElevenLabsTts(
  text: string,
  signal?: AbortSignal
): Promise<HTMLAudioElement> {
  const key = import.meta.env.VITE_ELEVENLABS_API_KEY?.trim();
  const voiceId = import.meta.env.VITE_ELEVENLABS_VOICE_ID?.trim();
  if (!key || !voiceId) {
    throw new Error("ElevenLabs is not configured.");
  }

  const res = await fetch(`https://api.elevenlabs.io/v1/text-to-speech/${voiceId}`, {
    method: "POST",
    headers: {
      "xi-api-key": key,
      "Content-Type": "application/json",
      Accept: "audio/mpeg",
    },
    body: JSON.stringify({
      text,
      model_id: "eleven_multilingual_v2",
    }),
    signal,
  });

  if (!res.ok) {
    const err = await res.text().catch(() => res.statusText);
    throw new Error(err || `ElevenLabs ${res.status}`);
  }

  const blob = await res.blob();
  const url = URL.createObjectURL(blob);
  const audio = new Audio(url);
  const revoke = () => URL.revokeObjectURL(url);
  audio.addEventListener("ended", revoke, { once: true });
  audio.addEventListener("error", revoke, { once: true });

  if (signal) {
    signal.addEventListener("abort", () => {
      audio.pause();
      URL.revokeObjectURL(url);
    });
  }

  await audio.play();
  return audio;
}
