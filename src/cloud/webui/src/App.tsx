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
    { coordinates: [5.58586, 43.60215], intensity: 8.5, status: 'active' },
  ];
  const windData: WindData[] = [
    { lat: 43.60215, lon: 5.58586, speed: 15, direction: 45 },
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