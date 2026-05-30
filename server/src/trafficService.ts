import {
  fetchDirectionsCondition,
  buildMockCondition,
  type Location,
  type TrafficStatus,
  type TrafficCondition,
} from './directionsService';

// ── Domain types ───────────────────────────────────────────────────────────

export type { Location, TrafficStatus, TrafficCondition };

export interface TrafficNotification {
  type: 'start_getting_cozy' | 'traffic_clearing';
  currentETA: string;
  delay: string;
}

export interface TrafficUpdate {
  userId: string;
  condition: TrafficCondition;
  notification?: TrafficNotification;
}

export interface MonitoringSession {
  userId: string;
  homeLocation: Location;
  currentLocation: Location;
  isActive: boolean;
  lastCheck?: TrafficCondition;
  notificationFrequencyMinutes: number;
}

// ── Internal session state ─────────────────────────────────────────────────

interface SessionState extends MonitoringSession {
  previousStatus?: TrafficStatus;
  lastNotificationTime?: number;
  tickInProgress: boolean;
  timer?: ReturnType<typeof setInterval>;
}

// ── Module-level maps ──────────────────────────────────────────────────────

const sessions = new Map<string, SessionState>();
const updateCallbacks = new Map<string, (update: TrafficUpdate) => void>();

// ── Helpers ────────────────────────────────────────────────────────────────

function formatMinutes(seconds: number): string {
  return `${Math.round(seconds / 60)} mins`;
}

function shouldNotify(session: SessionState, newStatus: TrafficStatus): boolean {
  if (session.previousStatus === undefined) return false;
  if (newStatus === session.previousStatus) return false;

  const cooldownMs =
    session.notificationFrequencyMinutes * 60_000 +
    (Math.random() * 60 - 30) * 1_000; // ±30 s jitter

  if (session.lastNotificationTime && Date.now() - session.lastNotificationTime < cooldownMs) {
    return false;
  }
  return true;
}

function buildNotification(
  condition: TrafficCondition,
  previousStatus: TrafficStatus
): TrafficNotification | undefined {
  if (condition.status === previousStatus) return undefined;

  const isWorsening =
    (previousStatus === 'calm' && condition.status !== 'calm') ||
    (previousStatus === 'bookey' && condition.status === "GG's");

  const delaySec = condition.durationInTraffic - condition.duration;

  return {
    type: isWorsening ? 'start_getting_cozy' : 'traffic_clearing',
    currentETA: formatMinutes(condition.durationInTraffic),
    delay: `+${formatMinutes(Math.max(0, delaySec))}`,
  };
}

// ── Async tick ─────────────────────────────────────────────────────────────

async function tick(userId: string): Promise<void> {
  const session = sessions.get(userId);
  if (!session || !session.isActive) return;

  // Guard against overlapping ticks (e.g. slow API response + interval fire).
  if (session.tickInProgress) {
    console.log(`[TrafficService] Skipping overlapping tick for ${userId}`);
    return;
  }

  session.tickInProgress = true;

  try {
    const result = await fetchDirectionsCondition(
      session.currentLocation,
      session.homeLocation
    );

    let condition: TrafficCondition;

    if (result.ok) {
      condition = result.condition;
      console.log(
        `[TrafficService] ${userId} — ${condition.status} ` +
        `(${Math.round(condition.durationInTraffic / 60)} min, source=${condition.dataSource})`
      );
    } else {
      // Log clearly for Logcat visibility, fall back to distance-aware mock.
      console.error(
        `[TrafficService] Directions fetch failed for ${userId}: ` +
        `reason=${result.reason}, detail=${result.detail}`
      );
      console.warn(`[TrafficService] Falling back to mock condition for ${userId}`);
      condition = buildMockCondition(session.currentLocation, session.homeLocation);
    }

    const previousStatus = session.previousStatus;
    let notification: TrafficNotification | undefined;

    if (previousStatus !== undefined && shouldNotify(session, condition.status)) {
      notification = buildNotification(condition, previousStatus);
      if (notification) {
        session.lastNotificationTime = Date.now();
        console.log(
          `[TrafficService] Notification for ${userId}: ` +
          `${notification.type} — ETA ${notification.currentETA}`
        );
      }
    }

    session.lastCheck = condition;
    session.previousStatus = condition.status;

    const callback = updateCallbacks.get(userId);
    if (callback) {
      callback({ userId, condition, notification });
    }
  } finally {
    session.tickInProgress = false;
  }
}

// ── Public API — identical interface to mockTrafficService ─────────────────

export function createSession(
  userId: string,
  homeLocation: Location,
  currentLocation: Location,
  frequency: number,
  onUpdate: (update: TrafficUpdate) => void
): MonitoringSession {
  const existing = sessions.get(userId);
  if (existing?.timer) clearInterval(existing.timer);

  const session: SessionState = {
    userId,
    homeLocation,
    currentLocation,
    isActive: true,
    notificationFrequencyMinutes: frequency,
    tickInProgress: false,
  };

  sessions.set(userId, session);
  updateCallbacks.set(userId, onUpdate);

  console.log(`[TrafficService] Session created for ${userId} (every ${frequency} min)`);

  // Immediate first tick, then on interval.
  setTimeout(() => tick(userId), 500);
  session.timer = setInterval(() => tick(userId), frequency * 60_000);

  return session;
}

export function getSession(userId: string): MonitoringSession | null {
  return sessions.get(userId) ?? null;
}

export function updateLocation(userId: string, location: Location): boolean {
  const session = sessions.get(userId);
  if (!session) return false;
  session.currentLocation = location;
  return true;
}

export function getTraffic(userId: string): TrafficCondition | null {
  return sessions.get(userId)?.lastCheck ?? null;
}

export function stopSession(userId: string): boolean {
  const session = sessions.get(userId);
  if (!session) return false;
  if (session.timer) clearInterval(session.timer);
  session.isActive = false;
  updateCallbacks.delete(userId);
  console.log(`[TrafficService] Session stopped for ${userId}`);
  return true;
}

export function updateSettings(
  userId: string,
  settings: { homeLocation?: Location; notificationFrequencyMinutes?: number }
): boolean {
  const session = sessions.get(userId);
  if (!session) return false;

  if (settings.homeLocation) session.homeLocation = settings.homeLocation;

  if (settings.notificationFrequencyMinutes !== undefined) {
    session.notificationFrequencyMinutes = settings.notificationFrequencyMinutes;
    if (session.timer) clearInterval(session.timer);
    const cb = updateCallbacks.get(userId);
    if (cb && session.isActive) {
      session.timer = setInterval(
        () => tick(userId),
        settings.notificationFrequencyMinutes * 60_000
      );
    }
  }
  return true;
}

export function forceCheck(userId: string): void {
  console.log(`[TrafficService] Force check requested for ${userId}`);
  tick(userId);
}
