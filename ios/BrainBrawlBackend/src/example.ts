import { BrainBrawlService, SabotageType, TutorPersona } from "./index";

const service = new BrainBrawlService();

service.seedBalance("p1", 500);
service.seedBalance("p2", 500);

const match = service.createMatch({
  challengerId: "p1",
  challengeId: "logic_rapid_01",
  wagerAmount: 100,
  tutor: TutorPersona.Magnus,
});

service.acceptMatch({
  matchId: match.id,
  opponentId: "p2",
  tutor: TutorPersona.Elara,
});

service.purchaseSabotage({
  matchId: match.id,
  sourcePlayerId: "p1",
  targetPlayerId: "p2",
  type: SabotageType.TimeWarp,
});

service.recordAnswer({
  matchId: match.id,
  playerId: "p1",
  questionId: "q1",
  isCorrect: true,
  responseMs: 1500,
  hasInteractionProof: true,
});

service.recordAnswer({
  matchId: match.id,
  playerId: "p2",
  questionId: "q1",
  isCorrect: true,
  responseMs: 5200,
  hasInteractionProof: true,
});

const finalized = service.finalizeByScore(match.id);
console.log(finalized.winnerId, service.getBalance("p1"), service.getBalance("p2"));
