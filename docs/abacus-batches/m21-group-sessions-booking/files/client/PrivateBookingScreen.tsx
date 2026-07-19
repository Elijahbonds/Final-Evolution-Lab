// Private 1-on-1 booking: slot picker from founder availability → note → pay &
// request → status. Founder mode lists pending requests with confirm/decline.

import { useEffect, useState } from 'react';
import type { SessionsResponse, PrivateBooking } from '../shared/sessionContracts';

export function PrivateBookingScreen(props: { onDone: () => void; isFounder?: boolean }) {
  const [data, setData] = useState<SessionsResponse | null>(null);
  const [slot, setSlot] = useState<string | null>(null);
  const [note, setNote] = useState('');
  const [busy, setBusy] = useState(false);
  const [msg, setMsg] = useState<string | null>(null);

  const load = () => fetch('/api/sessions').then((r) => r.json()).then(setData).catch(() => {});
  useEffect(() => { load(); }, []);

  const request = async () => {
    if (!slot) return;
    setBusy(true); setMsg(null);
    try {
      const res = await fetch('/api/sessions/book', {
        method: 'POST', headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ slotIso: slot, note }),
      });
      if (!res.ok) throw new Error((await res.json().catch(() => ({})))?.message ?? 'Booking failed');
      setMsg('Request sent! You’ll be confirmed shortly — shards are refunded if the time doesn’t work.');
      load();
    } catch (e: any) { setMsg(e.message); }
    finally { setBusy(false); }
  };

  if (!data) return <p className="p-6 text-center text-sm text-slate-400">Loading availability…</p>;

  const fmt = (iso: string) =>
    new Date(iso).toLocaleString(undefined, {
      weekday: 'short', month: 'short', day: 'numeric', hour: 'numeric',
      timeZone: data.config.timezone,
    });

  return (
    <div className="mx-auto max-w-md space-y-4 p-4">
      <header className="flex items-center justify-between">
        <h1 className="text-lg font-black tracking-wide">PRIVATE SESSION</h1>
        <button onClick={props.onDone} className="text-slate-500">✕</button>
      </header>

      <p className="text-sm text-slate-300">
        45 minutes, one-on-one, live. Movement review, corrective work, or
        biomechanics education — your call. <b>{data.config.privatePrice} ◆</b>,
        charged now and refunded if the slot can't be confirmed.
      </p>

      <section>
        <h3 className="mb-1 text-[11px] font-black tracking-widest text-slate-500">PICK A TIME</h3>
        <div className="grid grid-cols-2 gap-2">
          {data.bookingSlots.map((iso) => (
            <button key={iso} onClick={() => setSlot(iso)}
              className={`rounded-xl border p-2.5 text-sm font-semibold ${
                slot === iso ? 'border-amber-400 bg-amber-950/40' : 'border-slate-700 bg-slate-900'}`}>
              {fmt(iso)}
            </button>
          ))}
        </div>
        {data.bookingSlots.length === 0 && (
          <p className="text-sm text-slate-500">
            {data.seminarScheduled
              ? 'A seminar is scheduled — grab a seat there instead.'
              : 'No open slots in the next two weeks. Check back soon.'}
          </p>
        )}
      </section>

      <label className="block text-sm text-slate-300">
        What do you want to work on?
        <textarea value={note} onChange={(e) => setNote(e.target.value)} maxLength={500} rows={3}
          placeholder="e.g. My knee caves on landings — want to fix my jump mechanics."
          className="mt-1 w-full rounded-xl bg-slate-800 p-3 text-sm outline-none" />
      </label>

      <button disabled={!slot || busy} onClick={request}
        className="w-full rounded-xl bg-amber-400 py-3 font-black text-black disabled:opacity-40">
        {busy ? 'SENDING…' : `REQUEST SESSION · ${data.config.privatePrice} ◆`}
      </button>

      {msg && <p className="text-center text-sm text-slate-300">{msg}</p>}
      <p className="text-center text-[11px] text-slate-500">
        18+ only. Training guidance, not a medical consultation.
      </p>

      {props.isFounder && <FounderQueue />}
    </div>
  );
}

function FounderQueue() {
  const [pending, setPending] = useState<PrivateBooking[]>([]);
  const load = () =>
    fetch('/api/sessions/bookings?state=requested').then((r) => r.json()).then(setPending).catch(() => {});
  useEffect(() => { load(); }, []);

  const act = async (id: string, action: 'confirm' | 'decline') => {
    await fetch(`/api/sessions/bookings/${id}/${action}`, { method: 'POST' });
    load();
  };

  return (
    <section className="mt-6 border-t border-slate-800 pt-4">
      <h3 className="mb-2 text-[11px] font-black tracking-widest text-amber-400">
        FOUNDER — PENDING REQUESTS
      </h3>
      {pending.length === 0 && <p className="text-sm text-slate-500">Queue clear.</p>}
      {pending.map((b) => (
        <div key={b.id} className="mb-2 rounded-xl bg-slate-900 p-3 text-sm">
          <p className="font-semibold">{new Date(b.slotIso).toLocaleString()}</p>
          <p className="mt-0.5 text-[12px] text-slate-400">{b.note || '(no note)'}</p>
          <div className="mt-2 flex gap-2">
            <button onClick={() => act(b.id, 'confirm')}
              className="flex-1 rounded-lg bg-emerald-500 py-2 text-xs font-black text-black">CONFIRM</button>
            <button onClick={() => act(b.id, 'decline')}
              className="flex-1 rounded-lg bg-slate-700 py-2 text-xs font-black">DECLINE + REFUND</button>
          </div>
        </div>
      ))}
    </section>
  );
}
