export default function BodyScanSection() {
  return (
    <section id="body-scan" className="relative border-t border-white/5 py-24 sm:py-32 overflow-hidden">
      <div className="absolute inset-0 bg-[radial-gradient(ellipse_at_30%_50%,rgba(92,225,230,0.06),transparent_60%)]" />

      <div className="relative z-10 mx-auto max-w-7xl px-4 sm:px-6">
        <div className="grid lg:grid-cols-2 gap-16 items-center">
          {/* Left — Text */}
          <div>
            <p className="mb-3 text-[0.65rem] font-bold uppercase tracking-[0.35em] text-fel-cyan">
              OpenCap Integration
            </p>
            <h2 className="text-3xl font-black leading-tight tracking-tight sm:text-4xl">
              Your Body. <span className="text-fel-cyan">Scanned in 3D.</span>
            </h2>
            <p className="mt-4 text-white/60 leading-relaxed">
              Using OpenCap's markerless motion capture, Final Evolution Lab creates a full 3D
              biomechanical model from just two smartphone cameras. Get personalized insights
              that pros pay thousands for.
            </p>

            <div className="mt-8 space-y-4">
              {[
                {
                  title: 'Biomechanical Analysis',
                  desc: 'Joint angles, range of motion, asymmetries — measured with clinical precision.',
                  icon: '🦴',
                },
                {
                  title: 'AI Form Correction',
                  desc: 'Real-time feedback during exercises. Visual overlays, audio cues, and haptic alerts.',
                  icon: '🤖',
                },
                {
                  title: 'Injury Prevention',
                  desc: 'Detect movement compensations, track fatigue, and get corrective exercise prescriptions.',
                  icon: '🛡️',
                },
                {
                  title: 'Personalized Workouts',
                  desc: 'AI-generated workout programs tailored to your biomechanics, goals, and injury history.',
                  icon: '🏋️',
                },
              ].map(({ title, desc, icon }) => (
                <div key={title} className="flex gap-4">
                  <span className="text-2xl">{icon}</span>
                  <div>
                    <h4 className="text-sm font-bold text-white">{title}</h4>
                    <p className="mt-1 text-xs text-white/50">{desc}</p>
                  </div>
                </div>
              ))}
            </div>
          </div>

          {/* Right — How it works */}
          <div className="rounded-3xl border border-white/10 bg-white/[0.02] p-8">
            <h3 className="text-lg font-bold text-white mb-6">How It Works</h3>
            <div className="space-y-6">
              {[
                {
                  step: '1',
                  title: 'Set Up 2 Cameras',
                  desc: 'Place your phone at front and side view (or use 2 devices).',
                },
                {
                  step: '2',
                  title: 'Calibrate & Record',
                  desc: 'Perform calibration movements, then record a 30-second movement sequence.',
                },
                {
                  step: '3',
                  title: 'AI Processing',
                  desc: 'OpenCap creates a 3D skeletal model and extracts biomechanical data.',
                },
                {
                  step: '4',
                  title: 'Get Your Report',
                  desc: 'Joint analysis, performance metrics, injury risk assessment, and personalized recommendations.',
                },
                {
                  step: '5',
                  title: 'Train Smarter',
                  desc: 'AI-generated workouts adapt to your scan results. Track improvement over time.',
                },
              ].map(({ step, title, desc }) => (
                <div key={step} className="flex gap-4">
                  <div className="flex-shrink-0 w-8 h-8 rounded-full bg-fel-cyan/10 flex items-center justify-center">
                    <span className="text-xs font-bold text-fel-cyan">{step}</span>
                  </div>
                  <div>
                    <h4 className="text-sm font-bold text-white">{title}</h4>
                    <p className="mt-0.5 text-xs text-white/50">{desc}</p>
                  </div>
                </div>
              ))}
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}
