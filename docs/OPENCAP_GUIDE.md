# OpenCap Body Scanning Guide

## Overview

Final Evolution Lab integrates [OpenCap](https://www.opencap.ai/) — an open-source markerless motion capture system — to provide 3D biomechanical body scanning using only smartphone cameras.

## How It Works

### Recording Setup

1. **Set up 2 cameras** (front and side view, ~45° apart)
2. **Ensure good lighting** — avoid backlighting
3. **Wear form-fitting clothes** — avoid baggy clothing
4. **Clear the area** — 3m × 3m minimum space
5. **Camera height** — waist level, 3-4 meters away

### Recording Process

1. **Calibration** — Perform T-pose and basic movements
2. **Movement Sequence** — 30-60 second recording
3. **Upload** — Videos uploaded to OpenCap server
4. **Processing** — AI generates 3D skeleton (2-5 minutes)
5. **Results** — Full biomechanical analysis delivered

### Recommended Movement Sequences

| Scan Type | Movements | Duration |
|-----------|-----------|----------|
| Full Body | Walk, squat, jump, reach | 60s |
| Upper Body | Arm circles, overhead press, rotation | 30s |
| Lower Body | Squat, lunge, single-leg balance | 30s |
| Basketball | Shooting form, defensive slide, jump | 45s |

## Analysis Features

### Joint Analysis
- **Range of Motion (ROM)** — All major joints graded Excellent→Poor
- **Joint Angles** — Measured during movements
- **Asymmetries** — Left vs. right comparison
- **Mobility Limitations** — Identified and flagged
- **Flexibility Scores** — Benchmarked against population

### Movement Patterns
- **Squat Depth & Form** — Knee tracking, hip hinge, torso angle
- **Jump Mechanics** — Triple extension, arm swing, landing
- **Running Gait** — Stride length, cadence, foot strike
- **Shooting Form** — Elbow alignment, release point

### Performance Metrics
- Vertical Jump Height (cm)
- Sprint Speed (m/s)
- Agility Score (0-100)
- Power Output (Watts)
- Endurance Capacity (0-100)
- Flexibility Score (0-100)
- Balance Score (0-100)

## Form Correction AI

### Real-time Feedback Methods
1. **Visual Overlay** — Skeleton comparison on screen
2. **Audio Cues** — "Lower your hips", "Straighten your back"
3. **Haptic Feedback** — Controller vibration patterns
4. **Text Instructions** — On-screen correction messages
5. **Video Demonstrations** — Reference clips

### Sensitivity Levels
- **Beginner** (0.3) — Lenient, major issues only
- **Intermediate** (0.5) — Balanced feedback
- **Advanced** (0.7) — Strict form requirements
- **Elite** (0.9) — Clinical-grade precision

## Injury Prevention

### Risk Assessment
- Movement compensations detected
- Imbalance identification
- High-risk pattern flagging
- Injury probability estimation
- Fatigue level monitoring

### Alerts
- 🟡 **Moderate Risk** — Modify workout intensity
- 🟠 **High Risk** — Focus on mobility/corrective work
- 🔴 **Critical** — Rest recommended, seek professional help
- ⚠️ **Fatigue Threshold** — Stop and recover
- 📊 **Overtraining** — Schedule rest day within 48h

## Personalized Workouts

Based on your scan data, the AI generates:
- **Exercise selection** tailored to your biomechanics
- **Set/rep schemes** for your fitness level
- **Progression rate** based on recovery capacity
- **Alternative exercises** for any limitations
- **Periodization** aligned with your goals

### Training Goals
- Increase Vertical Jump
- Improve Speed
- Enhance Agility
- Build Strength
- Improve Flexibility
- Build Endurance
- Injury Rehabilitation
- General Fitness

## UE5 Integration

### C++ Classes
| File | Purpose |
|------|---------|
| `FELOpenCapIntegration.h/.cpp` | OpenCap API connection, video upload, session management |
| `FELBiomechanicsAnalyzer.h/.cpp` | Joint ROM analysis, movement pattern detection |
| `FELFormCorrectionAI.h/.cpp` | Real-time form correction during exercises |
| `FELInjuryPrevention.h/.cpp` | Risk assessment, fatigue tracking, alerts |
| `FELPersonalizedWorkouts.h/.cpp` | AI workout generation, training plans |

### Blueprint Events
- `OnBodyScanComplete` — Scan finished with results
- `OnFormCorrectionIssued` — Real-time correction available
- `OnInjuryAlertTriggered` — Risk alert fired
- `OnWorkoutGenerated` — New workout ready

## API Reference

### OpenCap API Endpoints
```
POST /v1/sessions                  — Create new session
POST /v1/sessions/{id}/upload      — Upload video files
POST /v1/sessions/{id}/calibrate   — Run calibration
GET  /v1/sessions/{id}/status      — Check processing status
GET  /v1/sessions/{id}/results     — Get skeleton data
GET  /v1/health                    — Connection test
```

## Privacy & Data

- Videos processed server-side, deleted after analysis
- Skeleton data stored in user's encrypted profile
- Body metrics never shared with third parties
- Users can delete scan history at any time
- HIPAA-compliant data handling
