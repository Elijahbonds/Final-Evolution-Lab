import { NextResponse } from 'next/server';
import bcrypt from 'bcryptjs';
import { z } from 'zod';
import { prisma } from '@/lib/db';
import { rateLimit, clientKeyFromHeaders } from '@/lib/rate-limit';
import { postLc } from '@/lib/ledger';

export const dynamic = 'force-dynamic';

const signupSchema = z.object({
  email: z.string().trim().toLowerCase().email('Valid email required'),
  password: z.string().min(6, 'Password must be 6+ characters').max(128),
  name: z.string().trim().min(1).max(60).optional().default('Athlete'),
});

function randAttr() {
  return Math.round((40 + Math.random() * 30) * 10) / 10;
}

export async function POST(req: Request) {
  try {
    // Rate limit: 5 signups per IP per 15 min
    const ip = clientKeyFromHeaders(req.headers);
    const rl = rateLimit(`signup:${ip}`, 5, 15 * 60 * 1000);
    if (!rl.ok) {
      return NextResponse.json(
        { error: 'Too many signup attempts. Please try again later.' },
        { status: 429, headers: { 'Retry-After': String(rl.retryAfterSec) } }
      );
    }

    const body = await req.json().catch(() => ({}));
    const parsed = signupSchema.safeParse(body);
    if (!parsed.success) {
      return NextResponse.json(
        { error: parsed.error.issues[0]?.message ?? 'Invalid input' },
        { status: 400 }
      );
    }
    const { email, password, name } = parsed.data;

    const hashed = await bcrypt.hash(password, 12);

    let user;
    try {
      user = await prisma.user.create({ data: { email, password: hashed, name } });
    } catch (e: any) {
      if (e?.code === 'P2002') {
        return NextResponse.json({ error: 'An account with this email already exists.' }, { status: 409 });
      }
      throw e;
    }

    await prisma.playerProfile.create({
      data: {
        userId: user.id,
        strength: randAttr(),
        speed: randAttr(),
        endurance: randAttr(),
        agility: randAttr(),
        power: randAttr(),
        flexibility: randAttr(),
        recovery: randAttr(),
        mental: randAttr(),
        labCredits: 500,
      },
    });
    await postLc(prisma, { userId: user.id, amount: 500, reason: 'Welcome grant', balanceAfter: 500, dedupeKey: `welcome:${user.id}` });

    return NextResponse.json({ ok: true });
  } catch (e) {
    console.error('signup error', e);
    return NextResponse.json({ error: 'Signup failed. Please try again.' }, { status: 500 });
  }
}
