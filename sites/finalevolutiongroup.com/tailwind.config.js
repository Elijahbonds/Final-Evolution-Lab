/** @type {import('tailwindcss').Config} */
export default {
  content: ["./index.html", "./src/**/*.{ts,tsx}"],
  theme: {
    extend: {
      colors: {
        fel: {
          black: "#050608",
          deep: "#0a0c10",
          cyan: "#5ce1e6",
          blue: "#1e90ff",
          navy: "#0d2840",
        },
      },
      fontFamily: {
        sans: ['"SF Pro Display"', "system-ui", "-apple-system", "sans-serif"],
      },
    },
  },
  plugins: [],
};
