'use client';

import { useState } from 'react';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { signIn } from 'next-auth/react';
import { motion } from 'framer-motion';
import { Zap, Loader2 } from 'lucide-react';
import { toast } from 'sonner';

export function AuthForm({ mode }: { mode: 'login' | 'signup' }) {
  const router = useRouter();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [name, setName] = useState('');
  const [loading, setLoading] = useState(false);

  const submit = async (e: React.FormEvent) => {
    e?.preventDefault?.();
    if (loading) return;
    setLoading(true);
    try {
      if (mode === 'signup') {
        const res = await fetch('/api/signup', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ email, password, name }),
        });
        const j = await res.json().catch(() => ({}));
        if (!res.ok) {
          toast.error(j?.error ?? 'Signup failed');
          setLoading(false);
          return;
        }
      }
      const result = await signIn('credentials', { email, password, redirect: false });
      if (result?.error) {
        toast.error('Invalid email or password');
        setLoading(false);
        return;
      }
      router.replace('/');
    } catch {
      toast.error('Something went wrong');
      setLoading(false);
    }
  };

  return (
    <div className="flex min-h-screen items-center justify-center bg-[#050505] px-4">
      <div className="pointer-events-none fixed inset-0 overflow-hidden">
        <div className="absolute -top-40 left-1/2 h-96 w-96 -translate-x-1/2 rounded-full bg-[#00E5FF]/10 blur-[120px]" />
        <div className="absolute bottom-0 right-0 h-72 w-72 rounded-full bg-[#A855F7]/10 blur-[120px]" />
      </div>
      <motion.div
        initial={{ opacity: 0, y: 24 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.5 }}
        className="fel-panel relative w-full max-w-md rounded-xl p-8"
      >
        <div className="mb-8 text-center">
          <div className="mb-3 inline-flex h-14 w-14 items-center justify-center rounded-xl border border-[#00E5FF]/40 bg-[#00E5FF]/10">
            <Zap className="h-7 w-7 text-[#00E5FF]" />
          </div>
          <h1 className="fel-heading text-4xl font-bold">
            <span className="text-[#00E5FF] fel-glow-cyan">FINAL EVOLUTION</span> LAB
          </h1>
          <p className="mt-2 text-sm text-white/50">
            {mode === 'login' ? 'Enter the lab. Continue your evolution.' : 'Create your athlete profile.'}
          </p>
        </div>
        <form onSubmit={submit} className="space-y-4">
          {mode === 'signup' && (
            <input
              type="text"
              placeholder="Athlete name"
              value={name}
              onChange={(e) => setName(e?.target?.value ?? '')}
              className="w-full rounded-md border border-white/10 bg-[#16161A] px-4 py-3 text-sm text-white placeholder-white/30 outline-none transition-colors focus:border-[#00E5FF]/60"
            />
          )}
          <input
            type="email"
            required
            placeholder="Email"
            value={email}
            onChange={(e) => setEmail(e?.target?.value ?? '')}
            className="w-full rounded-md border border-white/10 bg-[#16161A] px-4 py-3 text-sm text-white placeholder-white/30 outline-none transition-colors focus:border-[#00E5FF]/60"
          />
          <input
            type="password"
            required
            minLength={6}
            placeholder="Password (6+ characters)"
            value={password}
            onChange={(e) => setPassword(e?.target?.value ?? '')}
            className="w-full rounded-md border border-white/10 bg-[#16161A] px-4 py-3 text-sm text-white placeholder-white/30 outline-none transition-colors focus:border-[#00E5FF]/60"
          />
          <button
            type="submit"
            disabled={loading}
            className="fel-heading flex w-full items-center justify-center gap-2 rounded-md bg-[#00E5FF] py-3 text-lg font-bold text-black transition-all hover:bg-[#00E5FF]/85 hover:shadow-[0_0_24px_rgba(0,229,255,0.45)] disabled:opacity-50"
          >
            {loading ? <Loader2 className="h-5 w-5 animate-spin" /> : mode === 'login' ? 'ENTER THE LAB' : 'BEGIN EVOLUTION'}
          </button>
        </form>
        <p className="mt-6 text-center text-sm text-white/50">
          {mode === 'login' ? (
            <>
              New athlete?{' '}
              <Link href="/signup" className="font-semibold text-[#00E5FF] hover:underline">
                Create account
              </Link>
            </>
          ) : (
            <>
              Already registered?{' '}
              <Link href="/login" className="font-semibold text-[#00E5FF] hover:underline">
                Sign in
              </Link>
            </>
          )}
        </p>
      </motion.div>
    </div>
  );
}
