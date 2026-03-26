/** @type {import('tailwindcss').Config} */
export default {
  content: ["./index.html", "./src/**/*.{js,ts,jsx,tsx}"],
  theme: {
    extend: {
      colors: {
        fel: {
          black: "#000000",
          cyan: "#5ce1e6",
          red: "#ff3355",
          amber: "#fcee0a",
        },
      },
    },
  },
  plugins: [],
};
