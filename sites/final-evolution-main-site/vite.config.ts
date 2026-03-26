import { defineConfig, loadEnv } from "vite";
import react from "@vitejs/plugin-react";

export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, process.cwd(), "");
  const paypalClientId = env.VITE_PAYPAL_CLIENT_ID || "sb";

  return {
    server: {
      proxy: {
        "/download/final-evolution": {
          target: "https://rlqkschgvlrva-wsdzjxq.supabase.co",
          changeOrigin: true,
          rewrite: () => "/storage/v1/object/public/sovereign-assets/mac/SovereignLab_1.0_Gold.dmg",
        },
      },
    },
    plugins: [
      react(),
      {
        name: "inject-paypal-client-id",
        transformIndexHtml(html: string) {
          return html.replace(/YOUR_PAYPAL_CLIENT_ID/g, paypalClientId);
        },
      },
    ],
  };
});
