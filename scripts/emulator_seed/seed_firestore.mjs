#!/usr/bin/env node
/**
 * Seeds the Firestore emulator with stub docs for local MVP testing.
 * Run while emulators are up: FIRESTORE_EMULATOR_HOST=127.0.0.1:8085 node seed_firestore.mjs
 *
 * Project ID must match `.firebaserc` default (or pass FIREBASE_PROJECT_ID).
 */
import { initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";

const host = process.env.FIRESTORE_EMULATOR_HOST || "127.0.0.1:8085";
process.env.FIRESTORE_EMULATOR_HOST = host;

const projectId =
  process.env.FIREBASE_PROJECT_ID ||
  process.env.GCLOUD_PROJECT ||
  "demo-fel-local";

initializeApp({ projectId });
const db = getFirestore();

await db.doc("_emulator_meta/seed").set({
  seededAt: new Date().toISOString(),
  note: "Stub catalog for emulator smoke tests; Swift app still uses bundled CreatorCard.catalog.",
});

const creatorCards = [
  {
    id: "coach_v_elite",
    creatorName: "Coach V",
    title: "Coach V Elite Card",
    costShards: 500,
  },
  {
    id: "bonds_bounce",
    creatorName: "Bonds Bounce",
    title: "Bonds Bounce Blueprint",
    costShards: 750,
  },
  {
    id: "flight_lab",
    creatorName: "Flight Lab",
    title: "Flight Lab Pro Card",
    costShards: 600,
  },
];

for (const c of creatorCards) {
  await db.doc(`catalog/creator_cards/cards/${c.id}`).set({
    ...c,
    kind: "creator_card_stub",
    updatedAt: new Date().toISOString(),
  });
}

const modules = [
  {
    id: "me_foundations",
    title: "Movement Education — Foundations",
    track: "foundations",
    weeks: 6,
  },
  {
    id: "me_flight",
    title: "Movement Education — Flight",
    track: "flight",
    weeks: 8,
  },
  {
    id: "me_elite",
    title: "Movement Education — Elite",
    track: "elite",
    weeks: 12,
  },
];

for (const m of modules) {
  await db.doc(`education/modules/items/${m.id}`).set({
    ...m,
    kind: "education_module_stub",
    updatedAt: new Date().toISOString(),
  });
}

console.log(
  `Firestore emulator (${host}) seeded: catalog/creator_cards/cards/*, education/modules/items/*, _emulator_meta/seed`
);
