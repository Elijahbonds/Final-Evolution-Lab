import React from "react";
import ReactDOM from "react-dom/client";
import App from "./App";
import { GlobalAudioProvider } from "./providers/GlobalAudioProvider";
import "./index.css";

ReactDOM.createRoot(document.getElementById("root")!).render(
  <React.StrictMode>
    <GlobalAudioProvider>
      <App />
    </GlobalAudioProvider>
  </React.StrictMode>
);
