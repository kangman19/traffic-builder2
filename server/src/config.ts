import * as dotenv from 'dotenv';
import * as path from 'path';

dotenv.config({ path: path.resolve(__dirname, '../.env') });

export const serverConfig = {
  port: parseInt(process.env.PORT ?? '3001', 10),
  googleMapsApiKey: (process.env.GOOGLE_MAPS_DIRECTIONS_API_KEY ?? '').trim(),
  nominatimEndpoint: (
    process.env.NOMINATIM_SEARCH_ENDPOINT ?? 'https://nominatim.openstreetmap.org'
  ).replace(/\/$/, ''),
} as const;

export function hasGoogleMapsKey(): boolean {
  return serverConfig.googleMapsApiKey.length > 0;
}
