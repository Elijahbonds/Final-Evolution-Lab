import React from 'react';
import { Link } from 'react-router-dom';

/**
 * FEL mode hub — every live playable slice, one tap away. Route: /play
 * Static list (route ↔ registry id ↔ archetype); modes without a route yet
 * appear as COMING SOON so the lineup vision stays visible.
 */
const LIVE = [
  { route: '/play/dunk',       title: 'Dunk Contest',   sub: 'Venice Beach at sunset',    icon: '🏀', arch: 'COURT' },
  { route: '/play/karate',     title: 'Karate Dojo',    sub: 'Over-shoulder spacing war', icon: '🥋', arch: 'COURT' },
  { route: '/play/football',   title: 'Street Football', sub: 'Jukes for six',            icon: '🏈', arch: 'COURT' },
  { route: '/play/soccer',     title: 'Penalty Shootout', sub: 'First to five shots',     icon: '⚽', arch: 'RALLY' },
  { route: '/play/tennis',     title: 'Clay Rally',     sub: 'Timing is everything',      icon: '🎾', arch: 'RALLY' },
  { route: '/play/golf',       title: 'Links Golf',     sub: 'Charge and release',        icon: '⛳', arch: 'RALLY' },
  { route: '/play/volleyball', title: 'Sand Volleyball', sub: 'Win the rally windows',    icon: '🏐', arch: 'RALLY' },
  { route: '/play/skate',      title: 'Venice Strip',   sub: 'Ollie · grind · repeat',    icon: '🛹', arch: 'CARVE' },
  { route: '/play/baseball',   title: 'Home Run Derby', sub: 'Swing the window',          icon: '⚾', arch: 'RALLY' },
  { route: '/play/snowboard',  title: 'Mountain Run',   sub: 'Steeper and faster',        icon: '🏂', arch: 'CARVE' },
  { route: '/play/surf',       title: 'Venice Break',   sub: 'Ride the trim line',        icon: '🏄', arch: 'CARVE' },
  { route: '/play/sprint',     title: '100m Dash',      sub: 'Alternate on the beat',     icon: '🏃', arch: 'RHYTHM' },
  { route: '/play/brain-brawl', title: 'Brain Brawl',   sub: 'Training science, timed',   icon: '🧠', arch: 'RHYTHM' },
  { route: '/play/who-scene-it', title: 'Who-Scene-It',  sub: 'Name the FEL scene',        icon: '🎬', arch: 'RHYTHM' },
  { route: '/play/gymnastics', title: 'Vault',          sub: 'Sprint · punch · stick it', icon: '🤸', arch: 'AIR' },
  { route: '/play/big-air',    title: 'Big Air',        sub: 'Kicker spins, clean lands', icon: '🎿', arch: 'AIR' },
  { route: '/irl/dunk',        title: 'IRL Dunk',       sub: 'Mirror Triumph · Couch H2H', icon: '🎥', arch: 'IRL' },
];

const SOON = [
  { title: 'Story Mode', icon: '📖' },
];

const ARCH_COLORS = { COURT: '#60a5fa', RALLY: '#34d399', CARVE: '#f472b6', RHYTHM: '#a78bfa', AIR: '#fb923c', IRL: '#facc15' };

export default function PlayHubPage() {
  return (
    <div style={pageStyle}>
      <header style={{ marginBottom: 22 }}>
        <h1 style={{ margin: 0, fontSize: 30, fontWeight: 900, letterSpacing: '0.05em' }}>THE LAB</h1>
        <div style={{ color: '#94a3b8', fontSize: 13 }}>
          Every mode, one spine. Pick your evolution.
        </div>
      </header>

      <div style={gridStyle}>
        {LIVE.map((m) => (
          <Link key={m.route} to={m.route} style={{ ...cardStyle, textDecoration: 'none' }}>
            <div style={{ fontSize: 34, lineHeight: 1 }}>{m.icon}</div>
            <div style={{ fontWeight: 800, fontSize: 16, color: '#f8fafc', marginTop: 8 }}>{m.title}</div>
            <div style={{ color: '#94a3b8', fontSize: 12, marginTop: 2 }}>{m.sub}</div>
            <div style={{
              marginTop: 10, alignSelf: 'flex-start', fontSize: 10, fontWeight: 800,
              letterSpacing: '0.1em', color: ARCH_COLORS[m.arch] ?? '#94a3b8',
              border: `1px solid ${ARCH_COLORS[m.arch] ?? '#94a3b8'}44`,
              padding: '3px 8px', borderRadius: 999,
            }}>
              {m.arch}
            </div>
          </Link>
        ))}
        {SOON.map((m) => (
          <div key={m.title} style={{ ...cardStyle, opacity: 0.4 }}>
            <div style={{ fontSize: 34, lineHeight: 1 }}>{m.icon}</div>
            <div style={{ fontWeight: 800, fontSize: 16, color: '#f8fafc', marginTop: 8 }}>{m.title}</div>
            <div style={{ color: '#94a3b8', fontSize: 11, marginTop: 2, letterSpacing: '0.08em' }}>COMING SOON</div>
          </div>
        ))}
      </div>
    </div>
  );
}

const pageStyle = {
  minHeight: '100vh', background: '#05070c', color: '#f8fafc',
  padding: '26px clamp(14px, 5vw, 48px)',
  fontFamily: 'system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif',
};
const gridStyle = {
  display: 'grid', gap: 14,
  gridTemplateColumns: 'repeat(auto-fill, minmax(180px, 1fr))',
};
const cardStyle = {
  display: 'flex', flexDirection: 'column',
  background: 'rgba(12,16,24,0.9)', border: '1px solid rgba(255,255,255,0.09)',
  borderRadius: 16, padding: 16, minHeight: 130,
};
