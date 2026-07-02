-- 1. Table to track individual sessions/events of gameplay engagement
CREATE TABLE IF NOT EXISTS public.user_mode_engagement (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    session_id TEXT NOT NULL,
    mode_id TEXT NOT NULL,
    status TEXT NOT NULL CHECK (status IN ('started', 'completed', 'abandoned', 'heartbeat')),
    started_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    ended_at TIMESTAMPTZ,
    duration_seconds INT NOT NULL DEFAULT 0,
    xp_earned INT NOT NULL DEFAULT 0,
    telemetry_summary JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Indexing for fast historical activity lookups
CREATE INDEX IF NOT EXISTS idx_user_engagement_lookup ON public.user_mode_engagement(user_id, mode_id, started_at DESC);
CREATE INDEX IF NOT EXISTS idx_user_session_lookup ON public.user_mode_engagement(session_id);

-- 2. Aggregated metrics table to populate user dashboard stats rapidly
CREATE TABLE IF NOT EXISTS public.user_mode_analytics (
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    mode_id TEXT NOT NULL,
    total_sessions INT NOT NULL DEFAULT 0,
    total_duration_seconds INT NOT NULL DEFAULT 0,
    total_xp INT NOT NULL DEFAULT 0,
    highest_score NUMERIC(10,2) DEFAULT 0.00,
    last_engaged_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, mode_id)
);

-- RLS (Row Level Security) Configuration
ALTER TABLE public.user_mode_engagement ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_mode_analytics ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist before creating
DROP POLICY IF EXISTS "Users can insert their own engagements" ON public.user_mode_engagement;
DROP POLICY IF EXISTS "Users can read their own engagements" ON public.user_mode_engagement;
DROP POLICY IF EXISTS "Users can read their own analytics" ON public.user_mode_analytics;

CREATE POLICY "Users can insert their own engagements"
    ON public.user_mode_engagement FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can read their own engagements"
    ON public.user_mode_engagement FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can read their own analytics"
    ON public.user_mode_analytics FOR SELECT
    USING (auth.uid() = user_id);

-- 3. Trigger function to update analytics whenever a session is completed
CREATE OR REPLACE FUNCTION public.sync_completed_session_analytics()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.status = 'completed' THEN
        INSERT INTO public.user_mode_analytics (
            user_id,
            mode_id,
            total_sessions,
            total_duration_seconds,
            total_xp,
            highest_score,
            last_engaged_at,
            updated_at
        )
        VALUES (
            NEW.user_id,
            NEW.mode_id,
            1,
            NEW.duration_seconds,
            NEW.xp_earned,
            COALESCE((NEW.telemetry_summary->>'score')::numeric, 0.00),
            NEW.started_at,
            now()
        )
        ON CONFLICT (user_id, mode_id) DO UPDATE
        SET 
            total_sessions = user_mode_analytics.total_sessions + 1,
            total_duration_seconds = user_mode_analytics.total_duration_seconds + NEW.duration_seconds,
            total_xp = user_mode_analytics.total_xp + NEW.xp_earned,
            highest_score = GREATEST(user_mode_analytics.highest_score, COALESCE((NEW.telemetry_summary->>'score')::numeric, 0.00)),
            last_engaged_at = NEW.started_at,
            updated_at = now();
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Recreate trigger cleanly
DROP TRIGGER IF EXISTS on_session_completed ON public.user_mode_engagement;
CREATE TRIGGER on_session_completed
    AFTER INSERT OR UPDATE ON public.user_mode_engagement
    FOR EACH ROW
    EXECUTE FUNCTION public.sync_completed_session_analytics();
