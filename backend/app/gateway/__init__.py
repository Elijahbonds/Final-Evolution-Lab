"""NEXUS Gateway — the versioned façade the Abacus web app consumes.

One stable surface (`/nexus/v1/*`) over the platform lanes:
sequencing (queue), education + marketplace (catalog), session ingest
(fan-out to prq/mastery/economy), and the CELL advisor.

Lanes plug in through :mod:`app.gateway.registry`; every capability has an
in-memory default so the gateway runs standalone.
"""
from __future__ import annotations

GATEWAY_API_VERSION = "v1"
