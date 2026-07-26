import {
  buildCard, validatePayload, royaltiesFor, rarityFor, Payloads, InvalidCard, MAX_SECONDARY,
} from '../creator/CardBridge.ts';

let pass = 0, fail = 0;
const ok = (n: string, c: boolean, x = '') => { c ? (pass++, console.log(`  ok   ${n}`)) : (fail++, console.log(`  FAIL ${n} ${x}`)); };
const throwsWith = (field: string, fn: () => unknown) => {
  try { fn(); return false; } catch (e) { return e instanceof InvalidCard && e.field === field; }
};

const artPayload = Payloads.art('data:image/png;base64,AAAA', ['#fff', '#000'], 'brush1', 'court');
const base = { ownerId: 'u1', title: 'Venice Blue', primary: 'art' as const, art: artPayload, licenseAccepted: true };

// happy path
const card = buildCard(base);
ok('builds a valid card', card.ownerId === 'u1' && card.primary === 'art');
ok('title is trimmed', buildCard({ ...base, title: '  Spaced  ' }).title === 'Spaced');
ok('defaults to private', card.isPublic === false);
ok('defaults to common rarity', card.rarity.tier === 'common' && card.rarity.statMultiplier === 1.0);
ok('licenseAccepted is literal true', card.licenseAccepted === true);

// the licence gate
ok('unaccepted licence is rejected', throwsWith('licenseAccepted', () => buildCard({ ...base, licenseAccepted: false })));
ok('title is required', throwsWith('title', () => buildCard({ ...base, title: '   ' })));
ok('owner is required', throwsWith('ownerId', () => buildCard({ ...base, ownerId: '' })));

// discipline rules
ok('at most 2 secondary', throwsWith('secondary',
   () => buildCard({ ...base, secondary: ['music', 'dance', 'acting'] })));
ok('exactly 2 secondary is fine', buildCard({ ...base, secondary: ['music', 'dance'] }).secondary.length === MAX_SECONDARY);
ok('primary cannot repeat in secondary', throwsWith('secondary', () => buildCard({ ...base, secondary: ['art'] })));
ok('duplicate secondary rejected', throwsWith('secondary', () => buildCard({ ...base, secondary: ['music', 'music'] })));

// sport designation
ok('sport primary needs a sport', throwsWith('sportDesignation',
   () => buildCard({ ...base, primary: 'sport', art: Payloads.sport({ routineId: 'r1' }) })));
ok('sport secondary needs a sport too', throwsWith('sportDesignation',
   () => buildCard({ ...base, secondary: ['sport'] })));
ok('sport designation accepted when sport involved',
   buildCard({ ...base, primary: 'sport', sportDesignation: 'basketball', art: Payloads.sport({ routineId: 'r1' }) }).sportDesignation === 'basketball');
ok('sport designation rejected when no sport', throwsWith('sportDesignation',
   () => buildCard({ ...base, sportDesignation: 'tennis' })));

// payload must match primary
ok('mismatched payload rejected', throwsWith('art',
   () => buildCard({ ...base, primary: 'music', art: artPayload })));

// per-discipline payload validation
ok('music needs stems', throwsWith('art.stemUrls', () => validatePayload(Payloads.music('t1', [], 120, 'Am'))));
ok('music needs positive bpm', throwsWith('art.bpm', () => validatePayload(Payloads.music('t1', ['s.wav'], 0, 'Am'))));
ok('art needs a real data url', throwsWith('art.canvasDataUrl', () => validatePayload(Payloads.art('http://x', ['#fff'], 'b', 'court'))));
ok('art needs a palette', throwsWith('art.palette', () => validatePayload(Payloads.art('data:image/png;base64,A', [], 'b', 'court'))));
ok('dance needs steps', throwsWith('art.sequence', () => validatePayload(Payloads.dance('c1', []))));
ok('acting needs a recording', throwsWith('art.performanceUrl', () => validatePayload(Payloads.acting('s1', ''))));
ok('sport needs at least one of three', throwsWith('art', () => validatePayload(Payloads.sport({}))));
ok('sport accepts a signature move alone', (() => { validatePayload(Payloads.sport({ signatureMoveId: 'm1' })); return true; })());

// moderation: UGC audio is gated by PAYLOAD, not by the caller
ok('music enters pending_review',
   buildCard({ ...base, primary: 'music', art: Payloads.music('t1', ['s.wav'], 120, 'Am') }).reviewState === 'pending_review');
ok('acting enters pending_review',
   buildCard({ ...base, primary: 'acting', art: Payloads.acting('s1', 'perf.wav') }).reviewState === 'pending_review');
ok('art is approved immediately', card.reviewState === 'approved');
ok('dance is approved immediately',
   buildCard({ ...base, primary: 'dance', art: Payloads.dance('c1', [{ clipId: 'x', beat: 0, holdBeats: 4, mirrored: false }]) }).reviewState === 'approved');

// rarity
ok('legendary multiplier is 1.6', rarityFor('legendary').statMultiplier === 1.6);
ok('unknown rarity rejected', throwsWith('rarity', () => rarityFor('mythic' as never)));

// ── remix royalties: FLAT, one hop only ──────────────────────────────────
const parent = { id: 'card_parent', ownerId: 'creatorA' };
const remix = buildCard({ ...base, ownerId: 'creatorB', remixOf: 'card_parent' });
const pay = royaltiesFor(remix, parent);
ok('remix pays the immediate parent', pay.length === 1 && pay[0].toUserId === 'creatorA' && pay[0].coins === 25);
ok('original card pays nobody', royaltiesFor(card, parent).length === 0);
ok('no self-payment for remixing yourself',
   royaltiesFor(buildCard({ ...base, ownerId: 'creatorA', remixOf: 'card_parent' }), parent).length === 0);
ok('mismatched parent pays nobody',
   royaltiesFor(remix, { id: 'someone_else', ownerId: 'creatorC' }).length === 0);
ok('missing parent pays nobody', royaltiesFor(remix, null).length === 0);
// the structural rule: a grandparent is NEVER paid
const grandchild = buildCard({ ...base, ownerId: 'creatorC', remixOf: remix.id });
const gpay = royaltiesFor(grandchild, { id: remix.id, ownerId: 'creatorB' });
ok('a remix-of-a-remix pays exactly one creator', gpay.length === 1);
ok('the grandparent is NOT paid — flat, not a downline',
   gpay.every(p => p.toUserId !== 'creatorA'));

console.log(`\n  ${pass} passed, ${fail} failed`);
process.exit(fail ? 1 : 0);
