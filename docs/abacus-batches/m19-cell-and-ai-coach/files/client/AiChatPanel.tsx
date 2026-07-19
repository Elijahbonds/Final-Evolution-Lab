// One chat component, two skins:
//   mode="panel"  → AI Coach inside the Coach tab (full height)
//   mode="orb"    → CELL floating orb over hub/result screens (expands to sheet)
// Streams replies, shows quick-action chips, carries the "AI" disclosure label.

import { useEffect, useRef, useState } from 'react';
import {
  QUICK_ACTIONS, type PersonaId, type ChatMessage, type SessionEvent,
} from '../shared/aiContracts';

async function streamChat(
  body: object, onChunk: (t: string) => void,
): Promise<{ threadId: string; reply: string; capRemaining: number }> {
  const res = await fetch('/api/ai/chat', {
    method: 'POST', headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });
  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  // SSE-or-JSON: if the server streams, accumulate; else parse once.
  if (res.headers.get('content-type')?.includes('text/event-stream') && res.body) {
    const reader = res.body.getReader();
    const dec = new TextDecoder();
    let full = '', meta: any = {};
    for (;;) {
      const { done, value } = await reader.read();
      if (done) break;
      for (const line of dec.decode(value).split('\n')) {
        if (!line.startsWith('data:')) continue;
        const evt = JSON.parse(line.slice(5));
        if (evt.chunk) { full += evt.chunk; onChunk(evt.chunk); }
        if (evt.done) meta = evt;
      }
    }
    return { threadId: meta.threadId, reply: full, capRemaining: meta.capRemaining ?? 0 };
  }
  const json = await res.json();
  onChunk(json.reply);
  return json;
}

export function AiChatPanel(props: {
  persona: PersonaId;
  mode: 'panel' | 'orb';
  /** result-screen integration: Cell auto-line for the session that just ended */
  sessionEvent?: SessionEvent;
}) {
  const [open, setOpen] = useState(props.mode === 'panel');
  const [messages, setMessages] = useState<ChatMessage[]>([]);
  const [draft, setDraft] = useState('');
  const [busy, setBusy] = useState(false);
  const threadId = useRef<string | undefined>(undefined);
  const scrollRef = useRef<HTMLDivElement>(null);
  const firedEvent = useRef(false);

  const isCell = props.persona === 'cell';
  const name = isCell ? 'CELL' : 'AI Coach';

  const push = (m: ChatMessage) => setMessages((prev) => [...prev, m]);
  const appendToLast = (t: string) =>
    setMessages((prev) => {
      const next = [...prev];
      next[next.length - 1] = { ...next[next.length - 1], content: next[next.length - 1].content + t };
      return next;
    });

  const send = async (text: string, event?: SessionEvent) => {
    if (busy || (!text.trim() && !event)) return;
    setBusy(true); setDraft('');
    if (text.trim()) push({ role: 'user', content: text, at: new Date().toISOString() });
    push({ role: 'assistant', content: '', at: new Date().toISOString() });
    try {
      const res = await streamChat(
        { persona: props.persona, message: text, threadId: threadId.current, event },
        appendToLast,
      );
      threadId.current = res.threadId;
    } catch {
      appendToLast(isCell ? '…connection dropped. Lucky you.' : 'Sorry — I lost connection. Try again?');
    } finally { setBusy(false); }
  };

  // Cell auto-line when a session just ended
  useEffect(() => {
    if (isCell && props.sessionEvent && !firedEvent.current) {
      firedEvent.current = true;
      setOpen(true);
      send('', props.sessionEvent);
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [props.sessionEvent]);

  useEffect(() => {
    scrollRef.current?.scrollTo({ top: scrollRef.current.scrollHeight });
  }, [messages]);

  if (props.mode === 'orb' && !open) return (
    <button onClick={() => setOpen(true)}
      aria-label="Chat with CELL"
      className="fixed bottom-24 right-4 z-40 flex h-14 w-14 items-center justify-center rounded-full bg-gradient-to-br from-fuchsia-500 to-cyan-400 shadow-lg shadow-fuchsia-500/30">
      <span className="text-lg font-black text-black">C</span>
    </button>
  );

  return (
    <div className={props.mode === 'orb'
      ? 'fixed inset-x-0 bottom-0 z-50 max-h-[70vh] rounded-t-3xl border-t border-slate-700 bg-slate-950 p-3'
      : 'flex h-full flex-col p-3'}>
      <header className="mb-2 flex items-center justify-between">
        <div className="flex items-center gap-2">
          <span className={`h-2.5 w-2.5 rounded-full ${isCell ? 'bg-fuchsia-400' : 'bg-emerald-400'}`} />
          <h2 className="font-black tracking-wide">{name}</h2>
          <span className="rounded bg-slate-800 px-1.5 text-[9px] font-bold text-slate-400">AI</span>
        </div>
        {props.mode === 'orb' && (
          <button onClick={() => setOpen(false)} className="text-slate-500">✕</button>
        )}
      </header>

      <div ref={scrollRef} className="min-h-40 flex-1 space-y-2 overflow-y-auto pb-2">
        {messages.length === 0 && (
          <p className="pt-6 text-center text-sm text-slate-500">
            {isCell ? 'Say something. I dare you.' : 'Ask me anything about your training.'}
          </p>
        )}
        {messages.map((m, i) => (
          <div key={i}
            className={`max-w-[85%] whitespace-pre-wrap rounded-2xl px-3 py-2 text-sm ${
              m.role === 'user'
                ? 'ml-auto bg-cyan-500/20 text-cyan-100'
                : isCell ? 'bg-fuchsia-500/10 text-fuchsia-100' : 'bg-slate-800 text-slate-100'
            }`}>
            {m.content || '…'}
          </div>
        ))}
      </div>

      <div className="flex gap-1 overflow-x-auto py-2">
        {QUICK_ACTIONS[props.persona].map((qa) => (
          <button key={qa.label} disabled={busy} onClick={() => send(qa.message)}
            className="shrink-0 rounded-full bg-slate-800 px-3 py-1 text-[11px] font-bold text-slate-300">
            {qa.label}
          </button>
        ))}
      </div>

      <div className="flex gap-2">
        <input value={draft} onChange={(e) => setDraft(e.target.value)}
          onKeyDown={(e) => e.key === 'Enter' && send(draft)}
          placeholder={isCell ? 'Talk to Cell…' : 'Ask your coach…'}
          className="flex-1 rounded-xl bg-slate-800 px-3 py-2 text-sm outline-none" />
        <button disabled={busy} onClick={() => send(draft)}
          className={`rounded-xl px-4 font-black text-black ${isCell ? 'bg-fuchsia-400' : 'bg-emerald-400'}`}>
          ➤
        </button>
      </div>
    </div>
  );
}
