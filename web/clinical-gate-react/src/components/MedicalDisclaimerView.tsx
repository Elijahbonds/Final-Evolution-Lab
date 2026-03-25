import React, { useState } from "react";

export interface MedicalDisclaimerViewProps {
  onAccept: () => void;
}

/**
 * Mandatory clinical gate — educational scope only (not medical clearance).
 * Copy aligned with Swift `MedicalDisclaimerView` / Bonds Standard.
 */
const MedicalDisclaimerView: React.FC<MedicalDisclaimerViewProps> = ({ onAccept }) => {
  const [ack, setAck] = useState(false);

  return (
    <div className="fixed inset-0 z-[1100] bg-black/95 flex items-center justify-center p-6 backdrop-blur-xl">
      <div className="max-w-2xl w-full bg-zinc-950 border border-cyan-500/30 p-8 md:p-12 rounded-3xl shadow-[0_0_80px_rgba(34,211,238,0.12)]">
        <h2 className="text-3xl md:text-4xl font-black tracking-tight text-cyan-400 mb-6">
          MEDICAL DISCLAIMER
        </h2>

        <div className="space-y-5 text-zinc-400 text-base md:text-lg leading-relaxed mb-8">
          <p>
            Final Evolution Lab provides <strong className="text-zinc-200">clinical movement education</strong> and
            athletic skill development. It is <strong className="text-zinc-200">not</strong> a medical device and does{" "}
            <strong className="text-zinc-200">not</strong> provide medical diagnosis, treatment, or rehabilitation
            plans.
          </p>

          <div className="p-5 bg-zinc-900/60 border border-zinc-800 rounded-2xl">
            <ul className="space-y-3 text-sm font-medium text-zinc-300">
              <li className="flex gap-3">
                <span className="text-cyan-500 shrink-0">01</span>
                <span>This is not medical advice.</span>
              </li>
              <li className="flex gap-3">
                <span className="text-cyan-500 shrink-0">02</span>
                <span>
                  PRQ, stiffness, and neural-drive visuals are <strong className="text-zinc-100">educational</strong> — not
                  a substitute for examination by a licensed clinician.
                </span>
              </li>
              <li className="flex gap-3">
                <span className="text-cyan-500 shrink-0">03</span>
                <span>
                  You assume responsibility for how you use training tools in the Lab. Stop if you feel pain or
                  unusual symptoms.
                </span>
              </li>
            </ul>
          </div>

          <p className="text-sm italic text-zinc-500">
            Consult a licensed physician before beginning any new protocol if you have health concerns.
          </p>
        </div>

        <label className="flex items-start gap-3 mb-6 cursor-pointer select-none">
          <input
            type="checkbox"
            className="mt-1 rounded border-zinc-600 text-cyan-500 focus:ring-cyan-500"
            checked={ack}
            onChange={(e) => setAck(e.target.checked)}
          />
          <span className="text-sm text-zinc-300">
            I have read and understand: Final Evolution is not medical advice.
          </span>
        </label>

        <button
          type="button"
          disabled={!ack}
          onClick={onAccept}
          className="w-full py-4 md:py-5 bg-cyan-500 disabled:bg-zinc-700 disabled:text-zinc-500 text-black font-black text-lg rounded-2xl hover:bg-cyan-400 enabled:shadow-[0_0_40px_rgba(34,211,238,0.25)] transition-all enabled:active:scale-[0.99]"
        >
          CONTINUE TO THE LAB
        </button>
      </div>
    </div>
  );
};

export default MedicalDisclaimerView;
