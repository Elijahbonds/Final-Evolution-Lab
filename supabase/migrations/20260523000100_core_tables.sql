-- Core Tables for Final Evolution Lab (consolidated to Supabase PostgreSQL)

-- 1. users
CREATE TABLE IF NOT EXISTS public.users (
    id TEXT PRIMARY KEY,
    data JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 2. user_sessions
CREATE TABLE IF NOT EXISTS public.user_sessions (
    id TEXT PRIMARY KEY,
    data JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 3. prq_metrics
CREATE TABLE IF NOT EXISTS public.prq_metrics (
    id TEXT PRIMARY KEY,
    data JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 4. health_metrics
CREATE TABLE IF NOT EXISTS public.health_metrics (
    id TEXT PRIMARY KEY,
    data JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 5. workout_logs
CREATE TABLE IF NOT EXISTS public.workout_logs (
    id TEXT PRIMARY KEY,
    data JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 6. game_sessions
CREATE TABLE IF NOT EXISTS public.game_sessions (
    id TEXT PRIMARY KEY,
    data JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 7. sovereign_sessions
CREATE TABLE IF NOT EXISTS public.sovereign_sessions (
    id TEXT PRIMARY KEY,
    data JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 8. streaks
CREATE TABLE IF NOT EXISTS public.streaks (
    id TEXT PRIMARY KEY,
    data JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 9. activity_feed
CREATE TABLE IF NOT EXISTS public.activity_feed (
    id TEXT PRIMARY KEY,
    data JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 10. critiques
CREATE TABLE IF NOT EXISTS public.critiques (
    id TEXT PRIMARY KEY,
    data JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 11. biofuel_logs
CREATE TABLE IF NOT EXISTS public.biofuel_logs (
    id TEXT PRIMARY KEY,
    data JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 12. biofuel_scans
CREATE TABLE IF NOT EXISTS public.biofuel_scans (
    id TEXT PRIMARY KEY,
    data JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 13. education_progress
CREATE TABLE IF NOT EXISTS public.education_progress (
    id TEXT PRIMARY KEY,
    data JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 14. education_lesson_engagement
CREATE TABLE IF NOT EXISTS public.education_lesson_engagement (
    id TEXT PRIMARY KEY,
    data JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 15. enrollments
CREATE TABLE IF NOT EXISTS public.enrollments (
    id TEXT PRIMARY KEY,
    data JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 16. kin_final_sessions
CREATE TABLE IF NOT EXISTS public.kin_final_sessions (
    id TEXT PRIMARY KEY,
    data JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 17. bio_digital_progress
CREATE TABLE IF NOT EXISTS public.bio_digital_progress (
    id TEXT PRIMARY KEY,
    data JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 18. bio_digital_completion_receipts
CREATE TABLE IF NOT EXISTS public.bio_digital_completion_receipts (
    id TEXT PRIMARY KEY,
    data JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 19. user_cards
CREATE TABLE IF NOT EXISTS public.user_cards (
    id TEXT PRIMARY KEY,
    data JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 20. payments
CREATE TABLE IF NOT EXISTS public.payments (
    id TEXT PRIMARY KEY,
    data JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Indices on JSONB data for performance
CREATE INDEX IF NOT EXISTS idx_users_user_id ON public.users USING gin (data);
CREATE INDEX IF NOT EXISTS idx_user_sessions_token ON public.user_sessions USING gin (data);
CREATE INDEX IF NOT EXISTS idx_prq_metrics_user_id ON public.prq_metrics USING gin (data);
CREATE INDEX IF NOT EXISTS idx_health_metrics_user_id ON public.health_metrics USING gin (data);
CREATE INDEX IF NOT EXISTS idx_workout_logs_user_id ON public.workout_logs USING gin (data);
CREATE INDEX IF NOT EXISTS idx_game_sessions_user_id ON public.game_sessions USING gin (data);
