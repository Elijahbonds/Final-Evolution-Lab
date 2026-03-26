import { defineConfig, loadEnv } from "vite";
import react from "@vitejs/plugin-react";

export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, process.cwd(), "");
  const paypalClientId = env.VITE_PAYPAL_CLIENT_ID || "sb";

  return {
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
