-- Multiplayer lobbies table for NEXUS match-relay
CREATE TABLE IF NOT EXISTS public.multiplayer_lobbies (
    id            TEXT        PRIMARY KEY DEFAULT gen_random_uuid()::text,
    room_code     TEXT        NOT NULL UNIQUE,
    host_user_id  TEXT        NOT NULL,
    mode_id       TEXT        NOT NULL,
    player_ids    JSONB       NOT NULL DEFAULT '[]'::jsonb,
    ready_ids     JSONB       NOT NULL DEFAULT '[]'::jsonb,
    status        TEXT        NOT NULL DEFAULT 'waiting'
                              CHECK (status IN ('waiting', 'active', 'ended')),
    max_players   INT         NOT NULL DEFAULT 2,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_multiplayer_lobbies_room_code
    ON public.multiplayer_lobbies (room_code);

CREATE INDEX IF NOT EXISTS idx_multiplayer_lobbies_status
    ON public.multiplayer_lobbies (status);

-- Auto-update updated_at on row change
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_multiplayer_lobbies_updated_at ON public.multiplayer_lobbies;
CREATE TRIGGER trg_multiplayer_lobbies_updated_at
  BEFORE UPDATE ON public.multiplayer_lobbies
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
