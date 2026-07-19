// SESSIONS surface (mounts inside FEL LIVE tab): group workouts (Wed/Fri 5:30),
// private seminars with seats, and the private-booking fallback when no seminar
// is on the calendar. Join buttons only go hot when the room is live.

import { useEffect, useState } from 'react';
import type { SessionsResponse, LiveSession } from '../shared/sessionContracts';

function when(iso: string, tz: string): string {
  return new Date(iso).toLocaleString(undefined, {
    weekday: 'short', month: 'short', day: 'numeric',
    hour: 'numeric', minute: '2-digit', timeZone: tz,
  });
}

export function GroupSessionsScreen(props: {
  onJoin: (session: LiveSession) => void;      // fetches /join then opens StreamPlayer
  onBook: () => void;                          // → PrivateBookingScreen
}) {
  const [data, setData] = useState<SessionsResponse | null>(null);
  const [busy, setBusy] = useState<string | null>(null);
  const [toast, setToast] = useState<string | null>(null);

  const load = () => fetch('/api/sessions').then((r) => r.json()).then(setData).catch(() => {});
  useEffect(() => { load(); }, []);

  const flash = (m: string) => { setToast(m); setTimeout(() => setToast(null), 2500); };

  const buyEntry = async (s: LiveSession) => {
    setBusy(s.id);
    try {
      const res = await fetch(`/api/sessions/${s.id}/ticket`, { method: 'POST' });
      if (!res.ok) throw new Error((await res.json().catch(() => ({})))?.message ?? 'Purchase failed');
      flash('You’re in! We’ll remind you before it starts.');
      load();
    } catch (e: any) { flash(e.message); }
    finally { setBusy(null); }
  };

  if (!data) return <p className="p-6 text-center text-sm text-slate-400">Loading sessions…</p>;
  const holding = new Set(data.mine.map((m) => m.sessionId));
  const workouts = data.upcoming.filter((s) => s.type === 'group_workout');
  const seminars = data.upcoming.filter((s) => s.type === 'private_seminar');

  const card = (s: LiveSession, kind: 'workout' | 'seminar') => {
    const mine = holding.has(s.id);
    const live = s.state === 'live';
    const full = s.attendeeCount >= s.capacity;
    return (
      <div key={s.id} className={`rounded-2xl border p-3 ${
        live ? 'border-rose-500/60' : kind === 'seminar' ? 'border-amber-500/40' : 'border-slate-700'} bg-slate-900`}>
        <div className="flex items-start justify-between">
          <div>
            <p className="text-[10px] font-black tracking-widest text-cyan-300">
              {kind === 'seminar' ? 'PRIVATE SEMINAR' : 'GROUP WORKOUT'}
            </p>
            <h3 className="font-bold leading-tight">{s.title}</h3>
            {s.hostNote && <p className="mt-0.5 text-[11px] text-slate-400">{s.hostNote}</p>}
            <p className="mt-1 text-[11px] text-slate-400">
              {live ? '● LIVE NOW' : when(s.startsAt, data.config.timezone)}
              {' · '}{s.attendeeCount}/{s.capacity} in
            </p>
          </div>
          {!mine && <span className="font-mono text-sm text-amber-300">{s.priceShards} ◆</span>}
        </div>
        <button
          disabled={busy === s.id || (!mine && full)}
          onClick={() => (mine ? (live ? props.onJoin(s) : flash('Doors open when the session goes live.')) : buyEntry(s))}
          className={`mt-2 w-full rounded-xl py-2.5 text-sm font-black disabled:opacity-40 ${
            mine
              ? live ? 'bg-rose-500 text-white' : 'bg-slate-700 text-slate-200'
              : 'bg-cyan-400 text-black'}`}>
          {mine ? (live ? 'JOIN LIVE →' : 'ENTRY SECURED ✓')
            : full ? 'FULL' : kind === 'seminar' ? 'RESERVE SEAT' : 'GET ENTRY'}
        </button>
      </div>
    );
  };

  return (
    <div className="space-y-5">
      <section>
        <h3 className="mb-2 text-[11px] font-black tracking-widest text-slate-500">
          GROUP WORKOUTS · WED + FRI 5:30 PM
        </h3>
        <div className="space-y-2">{workouts.map((s) => card(s, 'workout'))}</div>
        {workouts.length === 0 && <p className="text-sm text-slate-500">Next week's sessions post soon.</p>}
      </section>

      <section>
        <h3 className="mb-2 text-[11px] font-black tracking-widest text-slate-500">
          PRIVATE EDUCATIONAL SEMINARS
        </h3>
        {data.seminarScheduled ? (
          <div className="space-y-2">{seminars.map((s) => card(s, 'seminar'))}</div>
        ) : (
          <div className="rounded-2xl border border-slate-700 bg-slate-900 p-4 text-center">
            <p className="text-sm text-slate-300">No seminars on the calendar right now.</p>
            <p className="mt-1 text-[11px] text-slate-500">
              Want direct time? Book a private online session instead.
            </p>
            <button onClick={props.onBook}
              className="mt-3 w-full rounded-xl bg-amber-400 py-3 font-black text-black">
              BOOK A PRIVATE SESSION · {data.config.privatePrice} ◆
            </button>
          </div>
        )}
      </section>

      {data.myBookings.length > 0 && (
        <section>
          <h3 className="mb-2 text-[11px] font-black tracking-widest text-slate-500">MY BOOKINGS</h3>
          {data.myBookings.map((b) => (
            <div key={b.id} className="mb-2 rounded-xl bg-slate-900 p-3 text-sm">
              <p className="font-semibold">{when(b.slotIso, data.config.timezone)}</p>
              <p className={`text-[11px] font-bold ${
                b.state === 'confirmed' ? 'text-emerald-400'
                : b.state === 'requested' ? 'text-amber-300' : 'text-slate-500'}`}>
                {b.state === 'requested' ? 'AWAITING CONFIRMATION'
                  : b.state === 'confirmed' ? 'CONFIRMED — join opens at start time'
                  : b.state.toUpperCase()}
              </p>
            </div>
          ))}
        </section>
      )}

      {toast && (
        <p className="fixed bottom-24 left-1/2 z-50 -translate-x-1/2 rounded-full bg-slate-800 px-4 py-2 text-xs font-bold">
          {toast}
        </p>
      )}
    </div>
  );
}
