export type ViewMode = 'risk' | 'surveillance';

export interface FirePoint {
  coordinates: [number, number];
  intensity: number;
  status: 'active' | 'contained' | 'monitoring';
}

export interface WindData {
  lat: number;
  lon: number;
  speed: number;
  direction: number;
}
