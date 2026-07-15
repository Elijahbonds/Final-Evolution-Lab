import { NextResponse } from 'next/server';
import { getServerSession } from 'next-auth';
import { authOptions } from '@/lib/auth';
import { prisma } from '@/lib/db';
import { getOrCreateProfile } from '@/lib/profile-service';
import { TRACKS } from '@/lib/game-data';
import { postLc } from '@/lib/ledger';

export const dynamic = 'force-dynamic';

export async function POST(req: Request) {
  try {
    const session = await getServerSession(authOptions);
    const userId = (session?.user as any)?.id;
    if (!userId) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });

    const body = await req.json().catch(() => ({}));
    const trackKey = String(body?.trackKey ?? '');
    const moduleKey = String(body?.moduleKey ?? '');
    const lessonId = String(body?.lessonKey ?? '');
    const lessonKey = `${moduleKey}/${lessonId}`;

    const track = TRACKS.find((t) => t?.key === trackKey);
    const mod = track?.modules?.find((m) => m?.key === moduleKey);
    const lesson = mod?.lessons?.find((l) => l?.key === lessonId);
    if (!track || !mod || !lesson) return NextResponse.json({ error: 'Unknown lesson' }, { status: 400 });

    const existing = await prisma.lessonProgress.findUnique({
      where: { userId_trackKey_lessonKey: { userId, trackKey, lessonKey } },
    });
    if (existing) return NextResponse.json({ ok: true, credits: 0, alreadyDone: true });

    await prisma.lessonProgress.create({ data: { userId, trackKey, lessonKey } });

    // +10 LC per lesson; +50 LC module checkpoint when a module is fully complete
    let credits = 10;
    const done = await prisma.lessonProgress.findMany({ where: { userId, trackKey } });
    const doneKeys = new Set(done?.map((d: any) => d?.lessonKey) ?? []);
    const moduleComplete = (mod?.lessons ?? []).every((l: any) => doneKeys.has(`${moduleKey}/${l?.key}`));
    if (moduleComplete) credits += 50;

    const profile = await getOrCreateProfile(userId);
    const newBalance = (profile?.labCredits ?? 0) + credits;
    await prisma.$transaction(async (tx) => {
      await tx.playerProfile.update({
        where: { userId },
        data: { labCredits: newBalance, xp: (profile?.xp ?? 0) + 20, lastActiveAt: new Date() },
      });
      await postLc(tx, {
        userId,
        amount: credits,
        reason: moduleComplete ? `Lesson + module checkpoint (${track.title})` : `Lesson complete (${track.title})`,
        balanceAfter: newBalance,
      });
    });

    return NextResponse.json({ ok: true, credits, moduleComplete, labCredits: newBalance });
  } catch (e) {
    console.error('education complete error', e);
    return NextResponse.json({ error: 'Failed to record lesson' }, { status: 500 });
  }
}
