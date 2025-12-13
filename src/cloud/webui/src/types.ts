export type ViewMode = 'risk' | 'surveillance';

export interface FirePoint {
  coordinates: [number, number];
  intensity: number;
  status: 'active' | 'contained' | 'monitoring';
}

export interface WindData {
  direction: number; // in degrees
  speed: number;     // in km/h
}
