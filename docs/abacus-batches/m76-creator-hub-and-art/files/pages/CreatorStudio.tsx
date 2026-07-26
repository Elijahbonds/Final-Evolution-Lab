// CreatorStudio — the page /creator has been 404ing for.
//
// M28 shipped CreatorHub (a discipline PICKER) and creatorCardApi (a server
// endpoint). Nothing connected them, so there was no page to route to: the
// picker had nowhere to send you and the API had nothing calling it. This is
// the host — pick a discipline, author the payload, publish a validated card.
//
// It deliberately owns no authoring UI of its own. Art editing is M28's
// ArtMode, music is the live /studio, dance routines come from DanceMode's
// results. Re-implementing any of those here would fork a surface that
// already works.

import React, { useState } from 'react';
import CreatorHub from '../creator/CreatorHub';
import ArtMode from '../modes/art/ArtMode';
import { buildCard, Payloads, InvalidCard } from '../creator/CardBridge';
import type { ArtPayload, CreatorCard, Discipline, SportDesignation } from '../creator/CreatorCardTypes';

type Stage = 'pick' | 'author' | 'publish';

export default function CreatorStudio({ userId, onSaved }: {
  userId: string;
  /** Wire to POST /api/cards (creatorCardApi.createCard). */
  onSaved: (card: CreatorCard) => Promise<void>;
}) {
  const [stage, setStage] = useState<Stage>('pick');
  const [primary, setPrimary] = useState<Discipline>('art');
  const [secondary, setSecondary] = useState<Discipline[]>([]);
  const [sport, setSport] = useState<SportDesignation | undefined>();
  const [payload, setPayload] = useState<ArtPayload | null>(null);
  const [title, setTitle] = useState('');
  const [licence, setLicence] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  async function publish() {
    setError(null);
    if (!payload) { setError('Finish your work before publishing.'); return; }
    try {
      setBusy(true);
      // Validated client-side FIRST so an invalid card never costs a round
      // trip — the server re-checks and stays authoritative.
      const card = buildCard({
        ownerId: userId, title, primary, secondary,
        sportDesignation: sport, art: payload, licenseAccepted: licence,
      });
      await onSaved(card);
      setStage('pick'); setPayload(null); setTitle(''); setLicence(false);
    } catch (e) {
      // InvalidCard names the offending field, so the message can be specific
      // instead of "something went wrong".
      setError(e instanceof InvalidCard ? `${e.field}: ${e.message}` : String(e));
    } finally {
      setBusy(false);
    }
  }

  if (stage === 'pick') {
    return (
      <CreatorHub onEnter={(p, s, sp) => {
        setPrimary(p); setSecondary(s); setSport(sp); setStage('author');
      }} />
    );
  }

  if (stage === 'author') {
    if (primary === 'art') {
      return (
        <ArtMode onPublish={(p) => {
          const d = p as { dataUrl: string; palette: string[]; brushSetId?: string; surface?: 'court' | 'board' | 'kit' | 'ui' };
          setPayload(Payloads.art(d.dataUrl, d.palette, d.brushSetId ?? 'default', d.surface ?? 'court'));
          setStage('publish');
        }} />
      );
    }
    // Every other discipline is authored in its own existing surface. Sending
    // the player there and back beats a second-rate editor built in here.
    const DEST: Record<Discipline, string> = {
      art: '/play/art', music: '/studio', dance: '/play/dance',
      acting: '/play/acting', sport: '/play/dunk',
    };
    return (
      <div className="p-8 text-center space-y-4">
        <h2 className="text-2xl font-black">{primary.toUpperCase()}</h2>
        <p className="opacity-70">
          {primary === 'music' && 'Build a track in the Studio, then come back — your published track becomes the card.'}
          {primary === 'dance' && 'Record a routine in Dance, then come back — your routine becomes the card.'}
          {primary === 'acting' && 'Record your lines, then come back.'}
          {primary === 'sport' && 'Set a highlight or signature move in a sport mode, then come back.'}
        </p>
        <a className="inline-block px-6 py-3 rounded-xl bg-orange-500 font-bold" href={DEST[primary]}>
          Go to {primary}
        </a>
        <button className="block mx-auto underline opacity-60" onClick={() => setStage('pick')}>back</button>
      </div>
    );
  }

  return (
    <div className="p-8 max-w-lg mx-auto space-y-4">
      <h2 className="text-2xl font-black">Publish card</h2>
      <input
        className="w-full px-4 py-3 rounded-xl bg-black/30"
        placeholder="Card title" value={title} onChange={(e) => setTitle(e.target.value)}
      />
      <label className="flex gap-3 items-start text-sm opacity-80">
        <input type="checkbox" checked={licence} onChange={(e) => setLicence(e.target.checked)} />
        <span>
          I own this work and accept the creator licence. Cards containing recorded
          audio are reviewed before they appear publicly.
        </span>
      </label>
      {error && <p className="text-red-400 text-sm">{error}</p>}
      <div className="flex gap-3">
        <button
          className="px-6 py-3 rounded-xl bg-emerald-500 font-bold disabled:opacity-40"
          disabled={busy || !licence || !title.trim()}
          onClick={publish}
        >
          {busy ? 'Publishing…' : 'Publish'}
        </button>
        <button className="px-6 py-3 rounded-xl bg-white/10" onClick={() => setStage('author')}>back</button>
      </div>
    </div>
  );
}
