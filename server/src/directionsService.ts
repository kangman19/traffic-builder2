import axios from 'axios';
import { serverConfig, hasGoogleMapsKey } from './config';

// ── Shared domain types ────────────────────────────────────────────────────

export interface Location {
  lat: number;
  long: number;
}

export type TrafficStatus = 'calm' | 'bookey' | "GG's";

export interface TrafficCondition {
  duration: number;           // normal travel time in seconds
  durationInTraffic: number;  // current travel time with traffic in seconds
  distance: number;           // route distance in metres
  status: TrafficStatus;
  timestamp: Date;
  eta: Date;
  dataSource: 'live' | 'mock';
}

// ── Result union ───────────────────────────────────────────────────────────

type FetchSuccess = { ok: true; condition: TrafficCondition };

type FetchFailure = {
  ok: false;
  reason:
    | 'missing_key'       // key absent in config
    | 'auth_denied'       // key present but rejected by Google
    | 'quota_exceeded'    // billing quota hit
    | 'network_error'     // timeout or HTTP error
    | 'parse_error';      // unexpected response shape
  detail: string;
};

export type DirectionsResult = FetchSuccess | FetchFailure;

// ── Constants ──────────────────────────────────────────────────────────────

const DIRECTIONS_API_URL = 'https://maps.googleapis.com/maps/api/directions/json';
const REQUEST_TIMEOUT_MS = 8_000;

// ── Status helpers ─────────────────────────────────────────────────────────

export function statusFromMultiplier(multiplier: number): TrafficStatus {
  if (multiplier < 1.3) return 'calm';
  if (multiplier <= 1.8) return 'bookey';
  return "GG's";
}

// ── Distance-aware mock ────────────────────────────────────────────────────
// Haversine formula gives realistic base duration so mock reflects pin positions.

export function buildMockCondition(from: Location, to: Location): TrafficCondition {
  const R = 6_371_000; // metres
  const toRad = (deg: number) => (deg * Math.PI) / 180;
  const dLat = toRad(to.lat - from.lat);
  const dLon = toRad(to.long - from.long);
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(from.lat)) * Math.cos(toRad(to.lat)) * Math.sin(dLon / 2) ** 2;
  const distanceM = Math.max(500, 2 * R * Math.asin(Math.sqrt(a)));

  // Assume 40 km/h average urban speed for the un-congested base time.
  const baseDuration = Math.round((distanceM / 40_000) * 3_600);
  const multiplier = 1.0 + Math.random() * 1.5;
  const durationInTraffic = Math.round(baseDuration * multiplier);
  const now = new Date();

  return {
    duration: baseDuration,
    durationInTraffic,
    distance: Math.round(distanceM),
    status: statusFromMultiplier(multiplier),
    timestamp: now,
    eta: new Date(now.getTime() + durationInTraffic * 1_000),
    dataSource: 'mock',
  };
}

// ── Live fetch ─────────────────────────────────────────────────────────────

export async function fetchDirectionsCondition(
  from: Location,
  to: Location
): Promise<DirectionsResult> {
  if (!hasGoogleMapsKey()) {
    console.log('[DirectionsService] No API key configured — returning mock condition');
    return { ok: true, condition: buildMockCondition(from, to) };
  }

  try {
    const response = await axios.get(DIRECTIONS_API_URL, {
      timeout: REQUEST_TIMEOUT_MS,
      params: {
        origin: `${from.lat},${from.long}`,
        destination: `${to.lat},${to.long}`,
        departure_time: 'now',
        traffic_model: 'best_guess',
        key: serverConfig.googleMapsApiKey,
      },
    });

    return parseDirectionsResponse(response.data);
  } catch (error: unknown) {
    if (axios.isAxiosError(error)) {
      const httpStatus = error.response?.status;
      if (httpStatus === 429) {
        return {
          ok: false,
          reason: 'quota_exceeded',
          detail: `HTTP 429 from Directions API`,
        };
      }
      return {
        ok: false,
        reason: 'network_error',
        detail: `HTTP ${httpStatus ?? 'unknown'}: ${error.message}`,
      };
    }
    return { ok: false, reason: 'network_error', detail: String(error) };
  }
}

// ── Response parser ────────────────────────────────────────────────────────

function parseDirectionsResponse(body: unknown): DirectionsResult {
  if (typeof body !== 'object' || body === null) {
    return { ok: false, reason: 'parse_error', detail: 'Response body is not an object' };
  }

  const payload = body as Record<string, unknown>;
  const apiStatus = payload['status'];
  const errorMessage = payload['error_message'];

  if (apiStatus === 'REQUEST_DENIED') {
    return {
      ok: false,
      reason: 'auth_denied',
      detail: `REQUEST_DENIED — ${errorMessage ?? 'check API key and billing'}`,
    };
  }
  if (apiStatus === 'OVER_DAILY_LIMIT' || apiStatus === 'OVER_QUERY_LIMIT') {
    return { ok: false, reason: 'quota_exceeded', detail: `API status: ${apiStatus}` };
  }
  if (apiStatus !== 'OK') {
    return { ok: false, reason: 'parse_error', detail: `Unexpected API status: ${apiStatus}` };
  }

  const routes = payload['routes'];
  if (!Array.isArray(routes) || routes.length === 0) {
    return { ok: false, reason: 'parse_error', detail: 'routes[] is empty or missing' };
  }

  const legs = (routes[0] as Record<string, unknown>)['legs'];
  if (!Array.isArray(legs) || legs.length === 0) {
    return { ok: false, reason: 'parse_error', detail: 'routes[0].legs[] is empty or missing' };
  }

  const leg = legs[0] as Record<string, unknown>;

  const durationSec = ((leg['duration'] as Record<string, unknown>)?.['value']) as number | undefined;
  const durationInTrafficSec = ((leg['duration_in_traffic'] as Record<string, unknown>)?.['value']) as number | undefined;
  const distanceM = ((leg['distance'] as Record<string, unknown>)?.['value']) as number | undefined;

  if (durationSec === undefined || distanceM === undefined) {
    return {
      ok: false,
      reason: 'parse_error',
      detail: `Null numeric fields — duration=${durationSec}, distance=${distanceM}`,
    };
  }

  const effectiveDurationInTraffic = durationInTrafficSec ?? durationSec;
  const multiplier = effectiveDurationInTraffic / durationSec;
  const now = new Date();

  return {
    ok: true,
    condition: {
      duration: durationSec,
      durationInTraffic: effectiveDurationInTraffic,
      distance: distanceM,
      status: statusFromMultiplier(multiplier),
      timestamp: now,
      eta: new Date(now.getTime() + effectiveDurationInTraffic * 1_000),
      dataSource: 'live',
    },
  };
}
