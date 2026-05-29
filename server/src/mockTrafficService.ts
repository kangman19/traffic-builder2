export interface Location {
  lat: number;
  long: number;
}

export type TrafficStatus = 'calm' | 'bookey' | "GG's";

export interface TrafficCondition {
  duration: number;
  durationInTraffic: number;
  distance: number;
  status: TrafficStatus;
  timestamp: Date;
  eta: Date;
}

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
  notificationThreshold: number;
  notificationFrequencyMinutes: number;
}

interface SessionState extends MonitoringSession {
  previousStatus?: TrafficStatus;
  lastNotificationTime?: number;
  timer?: ReturnType<typeof setInterval>;
}

const BASE_DURATION_SECONDS = 1800; // 30 minutes
const BASE_DISTANCE_METRES = 12000; // 12 km

const sessions = new Map<string, SessionState>();
const updateCallbacks = new Map<string, (update: TrafficUpdate) => void>();

function getStatus(multiplier: number): TrafficStatus {
  if (multiplier < 1.3) return 'calm';
  if (multiplier <= 1.8) return 'bookey';
  return "GG's";
}

function formatMinutes(seconds: number): string {
  return `${Math.round(seconds / 60)} mins`;
}

function generateRandomTraffic(session: SessionState): TrafficCondition {
  const multiplier = 1.0 + Math.random() * 1.5;
  const durationInTraffic = Math.round(BASE_DURATION_SECONDS * multiplier);
  const eta = new Date(Date.now() + durationInTraffic * 1000);

  return {
    duration: BASE_DURATION_SECONDS,
    durationInTraffic,
    distance: BASE_DISTANCE_METRES,
    status: getStatus(multiplier),
    timestamp: new Date(),
    eta,
  };
}

function shouldNotify(session: SessionState, newStatus: TrafficStatus): boolean {
  if (session.previousStatus === undefined) return false;
  if (newStatus === session.previousStatus) return false;

  const cooldownMs =
    session.notificationFrequencyMinutes * 60 * 1000 +
    (Math.random() * 60 - 30) * 1000; // ±30s jitter

  if (
    session.lastNotificationTime &&
    Date.now() - session.lastNotificationTime < cooldownMs
  ) {
    return false;
  }

  return true;
}

function buildNotification(
  condition: TrafficCondition,
  previousStatus: TrafficStatus
): TrafficNotification | undefined {
  const delaySeconds = condition.durationInTraffic - condition.duration;

  if (condition.status !== previousStatus) {
    const isWorsening =
      (previousStatus === 'calm' && condition.status !== 'calm') ||
      (previousStatus === 'bookey' && condition.status === "GG's");

    return {
      type: isWorsening ? 'start_getting_cozy' : 'traffic_clearing',
      currentETA: formatMinutes(condition.durationInTraffic),
      delay: `+${formatMinutes(Math.max(0, delaySeconds))}`,
    };
  }
  return undefined;
}

function tick(userId: string): void {
  const session = sessions.get(userId);
  if (!session || !session.isActive) return;

  const condition = generateRandomTraffic(session);
  const previousStatus = session.previousStatus;
  let notification: TrafficNotification | undefined;

  if (previousStatus !== undefined && shouldNotify(session, condition.status)) {
    notification = buildNotification(condition, previousStatus);
    if (notification) {
      session.lastNotificationTime = Date.now();
    }
  }

  session.lastCheck = condition;
  session.previousStatus = condition.status;

  const callback = updateCallbacks.get(userId);
  if (callback) {
    callback({ userId, condition, notification });
  }
}

export function createSession(
  userId: string,
  homeLocation: Location,
  currentLocation: Location,
  threshold: number,
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
    notificationThreshold: threshold,
    notificationFrequencyMinutes: frequency,
  };

  sessions.set(userId, session);
  updateCallbacks.set(userId, onUpdate);

  // Immediate first tick then on interval
  setTimeout(() => tick(userId), 500);
  session.timer = setInterval(() => tick(userId), frequency * 60 * 1000);

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
  return true;
}

export function updateSettings(
  userId: string,
  settings: {
    homeLocation?: Location;
    notificationThreshold?: number;
    notificationFrequencyMinutes?: number;
  }
): boolean {
  const session = sessions.get(userId);
  if (!session) return false;

  if (settings.homeLocation) session.homeLocation = settings.homeLocation;
  if (settings.notificationThreshold !== undefined)
    session.notificationThreshold = settings.notificationThreshold;
  if (settings.notificationFrequencyMinutes !== undefined) {
    session.notificationFrequencyMinutes = settings.notificationFrequencyMinutes;
    if (session.timer) clearInterval(session.timer);
    const cb = updateCallbacks.get(userId);
    if (cb && session.isActive) {
      session.timer = setInterval(
        () => tick(userId),
        settings.notificationFrequencyMinutes * 60 * 1000
      );
    }
  }
  return true;
}

export function forceCheck(userId: string): void {
  tick(userId);
}
