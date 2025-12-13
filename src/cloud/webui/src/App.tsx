// src/App.tsx
import { type Component, createSignal } from 'solid-js';
import './App.css'
import Header from './components/Header';
import InfoPanel from './components/InfoPanel';
import WindIndicator from './components/WindIndicator';
import MapContainer from './components/MapContainer';
import type { ViewMode, FirePoint, WindData } from './types';

const App: Component = () => {
  const [viewMode, setViewMode] = createSignal<ViewMode>('risk');

  // Sample data
  const firePoints: FirePoint[] = [
    { coordinates: [-122.4, 37.8], intensity: 8.5, status: 'active' },
    { coordinates: [-122.5, 37.7], intensity: 4.2, status: 'monitoring' },
    { coordinates: [-122.3, 37.9], intensity: 6.8, status: 'contained' },
  ];
  const windData: WindData[] = [
    { lat: 37.8, lon: -122.4, speed: 15, direction: 45 },
    { lat: 37.7, lon: -122.5, speed: 12, direction: 90 },
    { lat: 37.9, lon: -122.3, speed: 18, direction: 30 },
  ];

  const handleViewChange = (mode: ViewMode) => setViewMode(mode);

  return (
    <div class="dashboard">
      <Header viewMode={viewMode} onChange={handleViewChange} />

      <MapContainer viewMode={viewMode} firePoints={firePoints} windData={windData}>
        <InfoPanel viewMode={viewMode} />
        <WindIndicator direction={windData[0].direction} speed={windData[0].speed} />
      </MapContainer>
    </div>
  );
};

export default App;