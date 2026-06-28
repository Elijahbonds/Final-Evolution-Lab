import React, { useState, useEffect, useRef } from "react";
import axios from "axios";
import {
  Flame, Trophy, Users, Gamepad2, Star, Award, Crown, Medal,
  User, Heart, Search, Swords, Check, X as XIcon, Calendar,
  Gift, Zap, Upload, Video, MessageSquare, Palette, Shirt
} from "lucide-react";
import { API } from "@/config/api";

// ===================== STREAKS & REWARDS =====================
export const StreaksView = () => {
  const [streak, setStreak] = useState(null);
  const [rewards, setRewards] = useState(null);
  const [checkedIn, setCheckedIn] = useState(false);

  useEffect(() => {
    Promise.all([axios.get(`${API}/streaks`), axios.get(`${API}/streaks/rewards`)])
      .then(([s, r]) => { setStreak(s.data); setRewards(r.data); }).catch(console.error);
  }, []);

  const handleCheckin = async () => {
    try {
      const r = await axios.post(`${API}/streaks/checkin`);
      setStreak(r.data);
      setCheckedIn(true);
      // Refresh rewards
      const rw = await axios.get(`${API}/streaks/rewards`);
      setRewards(rw.data);
    } catch (e) { console.error(e); }
  };

  const last30 = [];
  for (let i = 29; i >= 0; i--) {
    const d = new Date(); d.setDate(d.getDate() - i);
    last30.push(d.toISOString().split('T')[0]);
  }

  return (
    <div className="space-y-8 fade-in">
      <div><p className="overline mb-1">DAILY DISCIPLINE</p><h1 className="text-4xl font-black" style={{ fontFamily: 'Barlow Condensed' }}>TRAINING STREAK</h1></div>

      {/* Streak Counter */}
      <div className="surface-active p-8 text-center" data-testid="streak-counter">
        <Flame className={`w-20 h-20 mx-auto mb-4 ${(streak?.current_streak || 0) > 0 ? 'text-orange-400' : 'text-zinc-600'}`} />
        <div className="metric-value text-7xl" style={{ color: (streak?.current_streak || 0) >= 7 ? '#FF6B00' : '#00E5FF' }}>{streak?.current_streak || 0}</div>
        <div className="metric-label mb-6">DAY STREAK</div>
        {!checkedIn ? (
          <button data-testid="streak-checkin" onClick={handleCheckin} className="btn-primary text-lg px-12 py-4 pulse-cyan">Check In Today</button>
        ) : (
          <div className="flex items-center justify-center gap-2 text-green-400"><Check className="w-6 h-6" /> Checked in! +{streak?.xp_earned || 25} XP, +{streak?.coins_earned || 10} Coins</div>
        )}
        {streak?.rewards?.length > 0 && (
          <div className="mt-4 space-y-2">{streak.rewards.map((r, i) => (
            <div key={i} className="badge-clinical inline-block mx-1" style={{ background: 'rgba(255,184,0,0.1)', borderColor: 'rgba(255,184,0,0.3)', color: '#FFB800' }}><Gift className="w-3 h-3 inline mr-1" />{r}</div>
          ))}</div>
        )}
      </div>

      {/* Calendar Heatmap */}
      <div className="surface-card p-6" data-testid="streak-calendar">
        <h2 className="text-xl font-bold mb-4" style={{ fontFamily: 'Barlow Condensed' }}>LAST 30 DAYS</h2>
        <div className="grid grid-cols-10 gap-2">
          {last30.map(d => {
            const active = streak?.daily_log?.includes(d);
            return <div key={d} className={`aspect-square rounded-sm ${active ? 'bg-cyan-400' : 'bg-zinc-800'}`} title={d}></div>;
          })}
        </div>
      </div>

      {/* Milestones */}
      <div data-testid="streak-milestones">
        <h2 className="text-xl font-bold mb-4" style={{ fontFamily: 'Barlow Condensed' }}>MILESTONES</h2>
        <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
          {rewards?.milestones?.map((m, i) => (
            <div key={i} className={`surface-card p-6 text-center ${m.unlocked ? 'border-l-2 border-cyan-400' : 'opacity-50'}`}>
              <div className="metric-value text-3xl mb-2">{m.days}</div>
              <div className="metric-label mb-2">DAYS</div>
              <div className="text-xs text-zinc-400">{m.reward}</div>
              {m.unlocked && <Check className="w-5 h-5 text-green-400 mx-auto mt-2" />}
            </div>
          ))}
        </div>
      </div>

      {/* Stats */}
      <div className="grid grid-cols-2 gap-4">
        <div className="surface-card p-6 text-center"><div className="metric-value text-3xl">{streak?.longest_streak || 0}</div><div className="metric-label">LONGEST STREAK</div></div>
        <div className="surface-card p-6 text-center"><div className="metric-value text-3xl">{streak?.daily_log?.length || 0}</div><div className="metric-label">TOTAL ACTIVE DAYS</div></div>
      </div>
    </div>
  );
};

// ===================== SOCIAL =====================
export const SocialView = () => {
  const [athletes, setAthletes] = useState([]);
  const [challenges, setChallenges] = useState([]);
  const [feed, setFeed] = useState([]);
  const [tab, setTab] = useState('discover');
  const [search, setSearch] = useState('');

  useEffect(() => {
    Promise.all([
      axios.get(`${API}/social/athletes`),
      axios.get(`${API}/social/challenges`),
      axios.get(`${API}/social/feed`)
    ]).then(([a, c, f]) => { setAthletes(a.data); setChallenges(c.data); setFeed(f.data); }).catch(console.error);
  }, []);

  const handleFollow = async (userId) => {
    try { await axios.post(`${API}/social/follow/${userId}`); } catch {}
  };

  const handleChallenge = async (userId, mode) => {
    try {
      const r = await axios.post(`${API}/social/challenge`, { target_id: userId, game_mode: mode || 'basketball_h2h' });
      setChallenges(prev => [r.data, ...prev]);
    } catch {}
  };

  return (
    <div className="space-y-8 fade-in">
      <div><p className="overline mb-1">COMMUNITY</p><h1 className="text-4xl font-black" style={{ fontFamily: 'Barlow Condensed' }}>SOCIAL</h1></div>

      <div className="flex gap-2">
        {['discover', 'challenges', 'feed'].map(t => (
          <button key={t} data-testid={`social-tab-${t}`} onClick={() => setTab(t)} className={`px-4 py-2 text-sm font-medium uppercase tracking-wide ${tab === t ? 'bg-cyan-400 text-black' : 'bg-zinc-800 text-zinc-400'}`}>{t}</button>
        ))}
      </div>

      {tab === 'discover' && (
        <div className="space-y-6" data-testid="discover-athletes">
          <div className="relative">
            <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-5 h-5 text-zinc-500" />
            <input data-testid="search-athletes" value={search} onChange={e => setSearch(e.target.value)} placeholder="Search athletes..." className="input-clinical pl-10" />
          </div>
          <div className="grid md:grid-cols-2 gap-4">
            {athletes.filter(a => a.name.toLowerCase().includes(search.toLowerCase())).map((a, i) => (
              <div key={i} className="surface-card p-5 card-hover" data-testid={`athlete-${a.user_id}`}>
                <div className="flex items-center gap-4 mb-3">
                  <div className="w-14 h-14 bg-zinc-800 rounded-full flex items-center justify-center"><User className="w-7 h-7 text-zinc-400" /></div>
                  <div className="flex-1"><h3 className="font-bold">{a.name}</h3><p className="text-sm text-cyan-400 capitalize">{a.sport}</p></div>
                  <div className="text-right"><div className="font-mono text-cyan-400">{a.prq_score}</div><div className="text-xs text-zinc-500">PRQ</div></div>
                </div>
                <div className="flex items-center gap-3 text-sm text-zinc-400 mb-4">
                  <span>Lvl {a.level}</span>
                  <span>{a.followers?.length || 0} followers</span>
                </div>
                <div className="flex gap-2">
                  <button data-testid={`follow-${a.user_id}`} onClick={() => handleFollow(a.user_id)} className="btn-secondary flex-1 text-sm py-2"><Users className="w-4 h-4 inline mr-1" />Follow</button>
                  <button data-testid={`challenge-${a.user_id}`} onClick={() => handleChallenge(a.user_id)} className="btn-primary flex-1 text-sm py-2"><Swords className="w-4 h-4 inline mr-1" />Challenge</button>
                </div>
              </div>
            ))}
          </div>
        </div>
      )}

      {tab === 'challenges' && (
        <div className="space-y-4" data-testid="challenges-list">
          {challenges.length === 0 ? (
            <div className="surface-card p-8 text-center"><Swords className="w-12 h-12 text-zinc-600 mx-auto mb-4" /><p className="text-zinc-400">No active challenges</p></div>
          ) : challenges.map((c, i) => (
            <div key={i} className="surface-card p-4 flex items-center justify-between">
              <div><h4 className="font-medium">vs {c.challenged_id || 'Opponent'}</h4><p className="text-sm text-zinc-400">{c.game_mode?.replace('_', ' ')}</p></div>
              <span className="badge-clinical">{c.status}</span>
            </div>
          ))}
        </div>
      )}

      {tab === 'feed' && (
        <div className="space-y-3" data-testid="activity-feed">
          {feed.length === 0 ? (
            <div className="surface-card p-8 text-center"><p className="text-zinc-400">No recent activity. Follow athletes to see their updates!</p></div>
          ) : feed.map((f, i) => (
            <div key={i} className="surface-card p-4 flex items-center gap-4">
              <div className={`w-10 h-10 rounded-full flex items-center justify-center ${f.type === 'workout' ? 'bg-green-400/10' : f.type === 'game' ? 'bg-blue-400/10' : 'bg-cyan-400/10'}`}>
                {f.type === 'workout' ? <Zap className="w-5 h-5 text-green-400" /> : f.type === 'game' ? <Gamepad2 className="w-5 h-5 text-blue-400" /> : <Users className="w-5 h-5 text-cyan-400" />}
              </div>
              <div className="flex-1"><span className="font-medium">{f.user_id}</span> <span className="text-zinc-400">{f.type === 'workout' ? `completed ${f.detail}` : f.type === 'game' ? `played ${f.detail} (${f.score} pts)` : `followed someone`}</span></div>
              <span className="text-xs text-zinc-600">{new Date(f.created_at).toLocaleDateString()}</span>
            </div>
          ))}
        </div>
      )}
    </div>
  );
};

// ===================== TOURNAMENTS =====================
export const TournamentsView = () => {
  const [tournaments, setTournaments] = useState([]);
  const [selected, setSelected] = useState(null);

  useEffect(() => { axios.get(`${API}/tournaments`).then(r => setTournaments(r.data)).catch(console.error); }, []);

  const handleJoin = async (id) => {
    try { await axios.post(`${API}/tournaments/${id}/join`); } catch {}
  };

  if (selected) {
    return (
      <div className="space-y-6 fade-in" data-testid="tournament-detail">
        <button onClick={() => setSelected(null)} className="btn-secondary text-sm">Back</button>
        <div className="surface-card p-6">
          <div className="flex items-center justify-between mb-6">
            <div>
              <div className="badge-clinical mb-2">{selected.format.replace('_', ' ')}</div>
              <h2 className="text-3xl font-bold" style={{ fontFamily: 'Barlow Condensed' }}>{selected.name}</h2>
              <p className="text-sm text-cyan-400">{selected.game_mode.replace('_', ' ')}</p>
            </div>
            <div className="text-right">
              <div className="metric-value text-2xl text-cyan-400">{selected.current_players}/{selected.max_players}</div>
              <div className="metric-label">PLAYERS</div>
            </div>
          </div>
          <div className="flex items-center gap-4 mb-6">
            <span className="badge-clinical">{selected.status}</span>
            <span className="text-sm text-zinc-400"><Calendar className="w-4 h-4 inline mr-1" />{selected.start_date}</span>
            <span className="text-sm text-yellow-400"><Trophy className="w-4 h-4 inline mr-1" />{selected.prize}</span>
          </div>
          {selected.status === 'registration' && <button data-testid="join-tournament" onClick={() => handleJoin(selected.id)} className="btn-primary mb-6">Join Tournament</button>}

          {/* Bracket */}
          {selected.bracket?.length > 0 && (
            <div>
              <h3 className="text-xl font-bold mb-4" style={{ fontFamily: 'Barlow Condensed' }}>BRACKET</h3>
              <div className="space-y-3">
                {selected.bracket.map((m, i) => (
                  <div key={i} className="surface-card p-4">
                    <div className="text-xs text-zinc-500 mb-2">Round {m.round} · Match {m.match}</div>
                    <div className="flex items-center justify-between">
                      <span className={`font-medium ${m.winner === m.player1 ? 'text-cyan-400' : ''}`}>{m.player1}</span>
                      <span className="text-zinc-600 font-mono">VS</span>
                      <span className={`font-medium ${m.winner === m.player2 ? 'text-cyan-400' : ''}`}>{m.player2}</span>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          )}
        </div>
      </div>
    );
  }

  return (
    <div className="space-y-8 fade-in">
      <div><p className="overline mb-1">COMPETITIVE PLAY</p><h1 className="text-4xl font-black" style={{ fontFamily: 'Barlow Condensed' }}>TOURNAMENTS</h1></div>
      <div className="grid md:grid-cols-2 gap-6" data-testid="tournaments-grid">
        {tournaments.map(t => (
          <div key={t.id} className="surface-card p-6 card-hover cursor-pointer" data-testid={`tournament-${t.id}`} onClick={() => setSelected(t)}>
            <div className="flex items-center justify-between mb-4">
              <div className="badge-clinical">{t.status}</div>
              <div className="text-right"><div className="font-mono text-cyan-400">{t.current_players}/{t.max_players}</div><div className="text-xs text-zinc-500">players</div></div>
            </div>
            <h3 className="text-xl font-bold mb-1" style={{ fontFamily: 'Barlow Condensed' }}>{t.name}</h3>
            <p className="text-sm text-zinc-400 mb-3">{t.game_mode.replace('_', ' ')} · {t.format.replace('_', ' ')}</p>
            <div className="flex items-center gap-3 text-sm">
              <span className="text-yellow-400"><Trophy className="w-4 h-4 inline mr-1" />{t.prize}</span>
              <span className="text-zinc-500">{t.start_date}</span>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
};

// ===================== AVATAR BUILDER =====================
export const AvatarBuilderView = () => {
  const [config, setConfig] = useState(null);
  const [options, setOptions] = useState(null);

  useEffect(() => {
    Promise.all([axios.get(`${API}/avatar/config`), axios.get(`${API}/avatar/options`)])
      .then(([c, o]) => { setConfig(c.data); setOptions(o.data); }).catch(console.error);
  }, []);

  const updateConfig = (key, value) => {
    const updated = { ...config, [key]: value };
    setConfig(updated);
  };

  const saveAvatar = async () => {
    try { await axios.put(`${API}/avatar/config`, config); } catch {}
  };

  if (!config || !options) return <div className="text-zinc-400">Loading avatar builder...</div>;

  return (
    <div className="space-y-8 fade-in">
      <div className="flex items-center justify-between">
        <div><p className="overline mb-1">CUSTOMIZE</p><h1 className="text-4xl font-black" style={{ fontFamily: 'Barlow Condensed' }}>AVATAR BUILDER</h1></div>
        <button data-testid="save-avatar" onClick={saveAvatar} className="btn-primary">Save Avatar</button>
      </div>

      <div className="grid lg:grid-cols-3 gap-8">
        {/* Preview */}
        <div className="surface-card p-6" data-testid="avatar-preview">
          <h3 className="text-lg font-bold mb-4" style={{ fontFamily: 'Barlow Condensed' }}>PREVIEW</h3>
          <div className="aspect-square bg-black/50 border border-white/10 flex items-center justify-center relative overflow-hidden">
            {/* Simple avatar visualization */}
            <div className="relative">
              <div className="w-20 h-20 rounded-full mb-2 mx-auto" style={{ background: config.skin_tone }}></div>
              <div className="w-24 h-32 rounded-t-lg mx-auto" style={{ background: config.jersey_color }}>
                <div className="text-center pt-4 text-xs font-bold" style={{ color: config.jersey_color === '#FFFFFF' ? '#000' : '#FFF' }}>FEL</div>
              </div>
              <div className="w-24 h-16 mx-auto" style={{ background: config.shorts_color }}></div>
              <div className="flex justify-center gap-2 mt-1">
                <div className="w-8 h-6 rounded-sm" style={{ background: config.shoe_color }}></div>
                <div className="w-8 h-6 rounded-sm" style={{ background: config.shoe_color }}></div>
              </div>
            </div>
            <div className="absolute top-2 right-2 text-xs text-zinc-500 font-mono">{config.body_type?.toUpperCase()}</div>
            <div className="absolute bottom-2 left-2 text-xs text-zinc-500 font-mono">{config.expression?.toUpperCase()}</div>
          </div>
        </div>

        {/* Options */}
        <div className="lg:col-span-2 space-y-6" data-testid="avatar-options">
          {[
            { key: 'body_type', label: 'Body Type', opts: options.body_types },
            { key: 'hair_style', label: 'Hair Style', opts: options.hair_styles },
            { key: 'expression', label: 'Expression', opts: options.expressions },
            { key: 'shoe_style', label: 'Shoe Style', opts: options.shoe_styles },
          ].map(section => (
            <div key={section.key}>
              <h4 className="metric-label mb-3">{section.label}</h4>
              <div className="flex flex-wrap gap-2">
                {section.opts.map(opt => (
                  <button key={opt} data-testid={`avatar-${section.key}-${opt}`}
                    onClick={() => updateConfig(section.key, opt)}
                    className={`px-4 py-2 text-sm capitalize ${config[section.key] === opt ? 'bg-cyan-400 text-black' : 'bg-zinc-800 text-zinc-400 hover:bg-zinc-700'}`}
                  >{opt}</button>
                ))}
              </div>
            </div>
          ))}

          {/* Color pickers */}
          {[
            { key: 'skin_tone', label: 'Skin Tone', opts: options.skin_tones },
            { key: 'jersey_color', label: 'Jersey Color', opts: options.jersey_colors },
            { key: 'shoe_color', label: 'Shoe Color', opts: options.shoe_colors },
          ].map(section => (
            <div key={section.key}>
              <h4 className="metric-label mb-3">{section.label}</h4>
              <div className="flex flex-wrap gap-2">
                {section.opts.map(color => (
                  <button key={color} data-testid={`avatar-${section.key}-${color.replace('#', '')}`}
                    onClick={() => updateConfig(section.key, color)}
                    className={`w-10 h-10 rounded-sm border-2 ${config[section.key] === color ? 'border-cyan-400 scale-110' : 'border-zinc-700'}`}
                    style={{ background: color }}
                  ></button>
                ))}
              </div>
            </div>
          ))}

          {/* Accessories */}
          <div>
            <h4 className="metric-label mb-3">Accessories</h4>
            <div className="flex flex-wrap gap-2">
              {options.accessories.map(acc => (
                <button key={acc} data-testid={`avatar-acc-${acc}`}
                  onClick={() => {
                    const current = config.accessories || [];
                    const updated = current.includes(acc) ? current.filter(a => a !== acc) : [...current, acc];
                    updateConfig('accessories', updated);
                  }}
                  className={`px-4 py-2 text-sm capitalize ${(config.accessories || []).includes(acc) ? 'bg-cyan-400 text-black' : 'bg-zinc-800 text-zinc-400'}`}
                >{acc.replace('_', ' ')}</button>
              ))}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};

// ===================== VIDEO CRITIQUE =====================
export const VideoCritiqueView = () => {
  const [critiques, setCritiques] = useState([]);
  const [uploading, setUploading] = useState(false);
  const [uploadedVideo, setUploadedVideo] = useState(null);
  const fileRef = useRef(null);

  useEffect(() => { axios.get(`${API}/coach/critiques`).then(r => setCritiques(r.data)).catch(console.error); }, []);

  const handleUpload = async (e) => {
    const file = e.target.files[0];
    if (!file) return;
    setUploading(true);
    const formData = new FormData();
    formData.append('file', file);
    try {
      const r = await axios.post(`${API}/uploads/video`, formData, { headers: { 'Content-Type': 'multipart/form-data' } });
      setUploadedVideo(r.data);
    } catch (err) { console.error(err); }
    setUploading(false);
  };

  const submitCritique = async (coachId) => {
    if (!uploadedVideo) return;
    try {
      const r = await axios.post(`${API}/coach/critique`, {
        coach_id: coachId, video_id: uploadedVideo.id, sport: 'basketball', notes: 'Please review my form'
      });
      setCritiques(prev => [r.data, ...prev]);
      setUploadedVideo(null);
    } catch {}
  };

  return (
    <div className="space-y-8 fade-in">
      <div><p className="overline mb-1">COACH FEEDBACK</p><h1 className="text-4xl font-black" style={{ fontFamily: 'Barlow Condensed' }}>VIDEO CRITIQUE</h1></div>

      {/* Upload */}
      <div className="surface-card p-8" data-testid="video-upload">
        <h2 className="text-xl font-bold mb-4" style={{ fontFamily: 'Barlow Condensed' }}>UPLOAD VIDEO FOR REVIEW</h2>
        <input ref={fileRef} type="file" accept="video/*" onChange={handleUpload} className="hidden" />
        <div className="border-2 border-dashed border-zinc-700 p-12 text-center cursor-pointer hover:border-cyan-400 transition-colors" onClick={() => fileRef.current?.click()}>
          {uploading ? (
            <div><div className="w-12 h-12 border-4 border-cyan-400 border-t-transparent rounded-full animate-spin mx-auto mb-4"></div><p className="text-zinc-400">Uploading...</p></div>
          ) : uploadedVideo ? (
            <div><Video className="w-12 h-12 text-green-400 mx-auto mb-4" /><p className="text-green-400">Uploaded: {uploadedVideo.filename}</p><p className="text-xs text-zinc-500 mt-1">{(uploadedVideo.size / (1024 * 1024)).toFixed(1)} MB</p></div>
          ) : (
            <div><Upload className="w-12 h-12 text-zinc-600 mx-auto mb-4" /><p className="text-zinc-400">Click to upload a training video</p><p className="text-xs text-zinc-600 mt-1">MP4, MOV, AVI up to 100MB</p></div>
          )}
        </div>
        {uploadedVideo && (
          <div className="mt-4 flex gap-3">
            <button data-testid="submit-to-coach-1" onClick={() => submitCritique('coach_1')} className="btn-primary flex-1">Send to Coach Williams</button>
            <button data-testid="submit-to-coach-2" onClick={() => submitCritique('coach_2')} className="btn-secondary flex-1">Send to Sensei Tanaka</button>
          </div>
        )}
      </div>

      {/* Critique History */}
      <div data-testid="critique-history">
        <h2 className="text-xl font-bold mb-4" style={{ fontFamily: 'Barlow Condensed' }}>MY CRITIQUES</h2>
        {critiques.length === 0 ? (
          <div className="surface-card p-8 text-center"><MessageSquare className="w-12 h-12 text-zinc-600 mx-auto mb-4" /><p className="text-zinc-400">No critiques yet. Upload a video to get started!</p></div>
        ) : (
          <div className="space-y-3">{critiques.map((c, i) => (
            <div key={i} className="surface-card p-4 flex items-center justify-between">
              <div><h4 className="font-medium">{c.sport} Review</h4><p className="text-sm text-zinc-400">{c.notes}</p></div>
              <div className="flex items-center gap-3">
                <span className="badge-clinical">{c.status}</span>
                {c.feedback && <span className="text-sm text-green-400">Feedback received</span>}
              </div>
            </div>
          ))}</div>
        )}
      </div>
    </div>
  );
};
