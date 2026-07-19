// One chat route for both AIs. Grounds in platform data, enforces safety + caps,
// calls the provider seam, streams the reply, persists threads.

import { PERSONAS } from '../shared/personas';
import {
  DAILY_MESSAGE_CAP,
  type ChatRequest, type ChatResponse, type ChatMessage, type GroundingContext, type PersonaId,
} from '../shared/aiContracts';

// ── Integration seams ───────────────────────────────────────────────────────
export interface LlmProvider {
  /** Bind to the Abacus AI endpoint / EMERGENT_LLM_KEY path. Server-side ONLY. */
  complete(args: {
    system: string;
    messages: ChatMessage[];
    maxTokens: number;
    temperature: number;
    onChunk?: (text: string) => void;      // streaming
  }): Promise<string>;
}
export interface Db {
  get<T>(c: string, id: string): Promise<T | null>;
  put<T>(c: string, id: string, doc: T): Promise<void>;
  delete(c: string, id: string): Promise<void>;
  incr(c: string, id: string, field: string, by: number): Promise<number>;
}
/** Pulls the same data the app already exposes; every field optional (fail soft). */
export interface ContextSource {
  build(userId: string): Promise<GroundingContext>;
}

type Ctx = { userId: string; llm: LlmProvider; db: Db; contextSource: ContextSource };

const C = { threads: 'ai_threads', usage: 'ai_usage' };
const THREAD_WINDOW = 16;               // last N messages sent to the model

// ── POST /api/ai/chat  (supports SSE streaming via onChunk) ─────────────────
export async function chat(
  ctx: Ctx, req: ChatRequest, onChunk?: (text: string) => void,
): Promise<ChatResponse> {
  const persona = PERSONAS[req.persona];
  if (!persona) throw err(400, 'unknown persona');

  // Daily cap across both personas
  const dayKey = `${ctx.userId}_${new Date().toISOString().slice(0, 10)}`;
  const used = await ctx.db.incr(C.usage, dayKey, 'messages', 1);
  if (used > DAILY_MESSAGE_CAP) {
    return { threadId: req.threadId ?? 'capped', reply: persona.cooldownLine, capRemaining: 0 };
  }

  const grounding = await ctx.contextSource.build(ctx.userId);
  const threadId = req.threadId ?? `${req.persona}_${ctx.userId}_${Date.now()}`;
  const thread =
    (await ctx.db.get<{ messages: ChatMessage[] }>(C.threads, threadId)) ?? { messages: [] };

  // Auto-line path: Cell reacts to a session event with no user message
  const userContent = req.event && persona.autoLinePrompt
    ? persona.autoLinePrompt(grounding, req.event)
    : req.message;
  if (!userContent?.trim()) throw err(422, 'empty message');

  const userMsg: ChatMessage = { role: 'user', content: userContent, at: new Date().toISOString() };
  const history = [...thread.messages.slice(-THREAD_WINDOW), userMsg];

  const reply = await ctx.llm.complete({
    system: persona.systemPrompt(grounding),
    messages: history,
    maxTokens: persona.maxTokens,
    temperature: persona.temperature,
    onChunk,
  });

  const assistantMsg: ChatMessage = { role: 'assistant', content: reply, at: new Date().toISOString() };
  await ctx.db.put(C.threads, threadId, {
    userId: ctx.userId, persona: req.persona,
    messages: [...thread.messages, userMsg, assistantMsg].slice(-100),
    updatedAt: assistantMsg.at,
  });

  return { threadId, reply, capRemaining: Math.max(0, DAILY_MESSAGE_CAP - used) };
}

// ── GET /api/ai/thread/:persona — latest thread for panel restore ──────────
export async function latestThread(
  ctx: Ctx, persona: PersonaId,
): Promise<{ threadId: string | null; messages: ChatMessage[] }> {
  // Simple convention: panel stores its threadId client-side; this is the fallback
  // lookup for fresh devices. Implement as an indexed query in the real db layer.
  const doc = await ctx.db.get<{ threadId: string; messages: ChatMessage[] }>(
    C.threads, `latest_${persona}_${ctx.userId}`,
  );
  return doc ? { threadId: doc.threadId, messages: doc.messages } : { threadId: null, messages: [] };
}

// ── DELETE /api/ai/threads — privacy: wipe my conversations ────────────────
export async function deleteThreads(ctx: Ctx): Promise<{ ok: true }> {
  // Real impl: delete-by-query on userId. Seam kept minimal here.
  await ctx.db.delete(C.threads, `latest_coach_${ctx.userId}`);
  await ctx.db.delete(C.threads, `latest_cell_${ctx.userId}`);
  return { ok: true };
}

function err(status: number, message: string): Error & { status: number } {
  const e = new Error(message) as Error & { status: number };
  e.status = status; return e;
}
