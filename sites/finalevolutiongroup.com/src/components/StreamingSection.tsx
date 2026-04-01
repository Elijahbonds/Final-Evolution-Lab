export default function StreamingSection() {
  return (
    <section id="streaming" className="border-t border-white/5 py-24 sm:py-32">
      <div className="mx-auto max-w-7xl px-4 sm:px-6">
        <div className="grid items-center gap-12 lg:grid-cols-2">
          <div>
            <p className="mb-3 text-[0.65rem] font-bold uppercase tracking-[0.35em] text-fel-cyan">
              Pixel Streaming
            </p>
            <h2 className="text-3xl font-black leading-tight tracking-tight sm:text-4xl">
              Play from Your <span className="text-fel-cyan">Browser</span>
            </h2>
            <p className="mt-4 text-white/60 leading-relaxed">
              Unreal Engine 5.7 renders all 12 game modes on a cloud GPU. Pixel Streaming delivers
              the full arena experience to any device with a browser — WebRTC, 60fps target, controller
              support via Gamepad API.
            </p>
            <div className="mt-8 space-y-4">
              {[
                { label: "Signalling Server", detail: "Wilbur — ws://host:8888 streamer, HTTP player frontend" },
                { label: "WebRTC Pipeline", detail: "STUN/TURN negotiation, hardware-encoded H.264/VP8" },
                { label: "Input Bridge", detail: "Mouse, keyboard, touch, DualSense via Gamepad API" },
                { label: "SFU Option", detail: "Mediasoup for multi-viewer simulcast fan-out" },
              ].map((item) => (
                <div key={item.label} className="rounded-lg border border-white/10 bg-white/[0.02] px-4 py-3">
                  <div className="text-xs font-bold uppercase tracking-wider text-fel-cyan">{item.label}</div>
                  <div className="mt-1 text-sm text-white/60">{item.detail}</div>
                </div>
              ))}
            </div>
          </div>

          {/* Streaming diagram */}
          <div className="rounded-2xl border border-white/10 bg-gradient-to-br from-white/[0.03] to-transparent p-8">
            <div className="space-y-4 text-center">
              <div className="rounded-xl border border-fel-cyan/30 bg-fel-cyan/5 p-4">
                <div className="text-xs font-bold uppercase tracking-wider text-fel-cyan">Unreal Engine 5.7</div>
                <div className="mt-1 text-[0.7rem] text-white/50">12 Arena Modes · PixelStreaming Plugin</div>
              </div>
              <div className="flex items-center justify-center">
                <div className="h-8 w-px bg-gradient-to-b from-fel-cyan/40 to-fel-blue/40" />
              </div>
              <div className="rounded-xl border border-fel-blue/30 bg-fel-blue/5 p-4">
                <div className="text-xs font-bold uppercase tracking-wider text-fel-blue">Wilbur Signalling</div>
                <div className="mt-1 text-[0.7rem] text-white/50">WebSocket · Port 8888 · Player Frontend</div>
              </div>
              <div className="flex items-center justify-center">
                <div className="h-8 w-px bg-gradient-to-b from-fel-blue/40 to-white/20" />
              </div>
              <div className="rounded-xl border border-white/20 bg-white/[0.03] p-4">
                <div className="text-xs font-bold uppercase tracking-wider text-white/70">Your Browser</div>
                <div className="mt-1 text-[0.7rem] text-white/50">WebRTC · 60fps · PWA Install</div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}
