# Family Sharing Guide

## Overview

Final Evolution Lab's Family Sharing lets you share your subscription with family members. Each person gets their own profile, progress tracking, and personalized experience.

## Subscription Tiers

| Plan | Price | Users | Savings |
|------|-------|-------|---------|
| Individual | $6/week | 1 | — |
| Family 2 | $10/week | 2 | $2/week vs 2× Individual |
| Family 5+ | $19.99/week | 5-10 | $10+/week vs 5× Individual |

All plans include:
- ✓ 17 Game Modes
- ✓ 23 Exercises
- ✓ Body Scanning
- ✓ Facial Animation
- ✓ Earn Shards
- ✓ Shard Store
- ✓ 72-hour free trial

## Getting Started

### Creating a Family

1. Subscribe to **Family 2** or **Family 5+** plan
2. Navigate to **Settings → Family Management**
3. Your family group is automatically created
4. You become the **Owner** with full control

### Inviting Members

#### Method 1: Invite Code
1. Go to **Family → Invite Member**
2. Click **Generate Code**
3. Share the code (format: `FEL-XXXX-XXXX`)
4. Member enters code during sign-up or in Settings
5. Code expires in 7 days

#### Method 2: Email Invitation
1. Go to **Family → Invite Member**
2. Enter member's email address
3. Click **Send Email**
4. Member receives link with embedded invite code

### Accepting an Invitation
1. Open the app or sign up
2. Go to **Settings → Join Family**
3. Enter the invite code
4. Confirm to join

## Member Roles

| Role | Permissions |
|------|-------------|
| **Owner** | Full control: manage plan, members, billing, parental controls |
| **Adult** | Full access to all features, can invite members |
| **Child** | Restricted access based on parental controls |

- Members under 13 are automatically assigned the **Child** role
- Only Owner can change billing or disband the family

## Individual Profiles

Each family member gets:
- **Separate save data** — Progress doesn't overlap
- **Personal progress tracking** — Individual stats and records
- **Individual customization** — Own avatar, settings, preferences
- **Private achievements** — Personal milestones
- **Own Shard wallet** — Earn and spend independently
- **Body scan data** — Individual biomechanical profiles

## Parental Controls

### Available Controls
- ☑ **Content filtering** — Age-appropriate content
- ☑ **Play time limits** — Set daily hour limit (default: 2 hours)
- ☑ **Allowed play times** — Set hours (e.g., 8 AM – 9 PM)
- ☑ **Require purchase approval** — Parent must approve shard spending
- ☐ **Multiplayer restrictions** — Limit online interactions

### Setting Up Parental Controls
1. Go to **Family → Members → [Child Name]**
2. Click **Edit Settings**
3. Toggle controls as needed
4. Save changes

### Alerts
- Notification when child exceeds playtime
- Notification for purchase approval requests
- Weekly activity summary email

## Family Features

### Family Leaderboard
- Compare stats across family members
- Weekly points based on workouts, games, and achievements
- Rankings updated in real-time

### Family Challenges
- Weekly family-wide challenges
- Complete together for bonus shards
- Track family progress

### Co-op Game Modes
- Play together in supported game modes
- Shared workout sessions
- Family tournaments

## Managing Your Plan

### Upgrading
- Go to **Settings → Subscription → Upgrade**
- Select new tier
- Price difference prorated
- New member slots available immediately

### Downgrading
- Only possible if current member count ≤ new tier max
- Remove extra members first if needed
- Takes effect at next billing cycle

### Removing Members
- Owner/Adults can remove members
- Members can leave voluntarily
- Owner cannot be removed (must disband family)

## UE5 Integration

### C++ Classes
| File | Purpose |
|------|---------|
| `FELFamilyManager.h/.cpp` | Family CRUD, invitations, parental controls |
| `FELSubscription.h` | Updated with family tier constants |

### Key Blueprint Functions
- `CreateFamily()` → Returns FamilyID
- `GenerateInviteCode()` → Returns invite code
- `AcceptInvite()` → Joins family
- `SetParentalControls()` → Configure child restrictions
- `GetFamilyLeaderboard()` → Sorted leaderboard data

### Events
- `OnFamilyCreated` — Family group created
- `OnMemberJoined` — New member added
- `OnMemberRemoved` — Member left/removed
- `OnTierChanged` — Subscription tier changed
