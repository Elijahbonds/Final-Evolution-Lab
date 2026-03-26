/// <reference types="vite/client" />

interface ImportMetaEnv {
  readonly VITE_SUPABASE_URL: string;
  readonly VITE_SUPABASE_ANON_KEY: string;
  /** PayPal app client id (public). Injected into index.html at build; default `sb` sandbox. */
  readonly VITE_PAYPAL_CLIENT_ID: string;
  /** Optional loop for hero when WebGL is unavailable or as ambient layer. */
  readonly VITE_HERO_VIDEO_URL: string;
}

interface ImportMeta {
  readonly env: ImportMetaEnv;
}
