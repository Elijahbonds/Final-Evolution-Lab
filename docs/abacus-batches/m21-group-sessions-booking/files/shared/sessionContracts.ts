// M21 — group sessions, seminars, and private booking contracts.
// ALL schedule/pricing knobs live here (single edit point).

export type SessionType = 'group_workout' | 'private_seminar' | 'private_1on1';

export interface SessionConfig {
  timezone: string;
  groupWorkout: {
    /** Standing schedule: day-of-week (0=Sun) + "HH:MM" local. */
    slots: { day: number; time: string }[];
    durationMin: number;
    capacity: number;
    priceShards: number;
    includedInMonthlyPass: boolean;
  };
  seminar: { defaultPriceShards: number; defaultCapacity: number };
  private1on1: {
    durationMin: number;
    priceShards: number;
    /** Availability template for booking slots. */
    availability: { day: number; from: string; to: string }[];
    /** Offer booking only when no seminar exists within this window. */
    fallbackWindowDays: number;
    minAge: number;
  };
}

/** ⚙ Current founder schedule: Wednesday + Friday 5:30 PM. */
export const SESSION_CONFIG: SessionConfig = {
  timezone: 'America/Los_Angeles',
  groupWorkout: {
    slots: [
      { day: 3, time: '17:30' },   // Wednesday 5:30 PM
      { day: 5, time: '17:30' },   // Friday 5:30 PM
    ],
    durationMin: 60,
    capacity: 100,
    priceShards: 150,
    includedInMonthlyPass: true,
  },
  seminar: { defaultPriceShards: 250, defaultCapacity: 25 },
  private1on1: {
    durationMin: 45,
    priceShards: 900,
    availability: [
      { day: 1, from: '16:00', to: '19:00' },  // Monday
      { day: 4, from: '16:00', to: '19:00' },  // Thursday
    ],
    fallbackWindowDays: 14,
    minAge: 18,
  },
};

// ── Sessions ────────────────────────────────────────────────────────────────

export interface LiveSession {
  id: string;
  type: SessionType;
  title: string;
  startsAt: string;                 // ISO
  durationMin: number;
  capacity: number;                 // 1 for private_1on1
  priceShards: number;
  state: 'scheduled' | 'live' | 'ended' | 'cancelled';
  attendeeCount: number;            // public count only — roster is server-side
  streamId?: string;                // M18 StreamMeta id once the room exists
  hostNote?: string;                // seminar topic blurb
}

// ── Entitlements ────────────────────────────────────────────────────────────

export interface SessionTicket {
  sessionId: string;
  userId: string;
  ledgerId: string;
  viaMonthlyPass: boolean;
  purchasedAt: string;
}

// ── Private booking ─────────────────────────────────────────────────────────

export type BookingState = 'requested' | 'confirmed' | 'declined' | 'completed' | 'cancelled';

export interface PrivateBooking {
  id: string;
  userId: string;
  slotIso: string;                  // requested start time
  note: string;                     // what the athlete wants to work on
  state: BookingState;
  ledgerId: string;                 // debit at request; refund on decline/cancel
  sessionId?: string;               // created on confirm
}

// ── API DTOs ────────────────────────────────────────────────────────────────

export interface SessionsResponse {
  upcoming: LiveSession[];              // group workouts + seminars, next 14 days
  mine: { sessionId: string }[];        // sessions this user holds entry to
  seminarScheduled: boolean;            // drives the booking fallback
  bookingSlots: string[];               // ISO slots (only when fallback active)
  myBookings: PrivateBooking[];
  config: Pick<SessionConfig, 'timezone'> & {
    groupPrice: number; seminarPrice: number; privatePrice: number;
  };
}

export interface JoinResponse { hlsUrl: string; token: string; expiresAt: string }
