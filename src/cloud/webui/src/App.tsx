// src/App.tsx
import { type Component, createSignal, onCleanup, onMount } from 'solid-js';
import './App.css'
import Header from './components/Header';
import InfoPanel from './components/InfoPanel';
import MapContainer from './components/MapContainer';
import type { ViewMode, WindData } from './types';
import type { FeatureCollection } from 'geojson';

const App: Component = () => {
  const [viewMode, setViewMode] = createSignal<ViewMode>('surveillance');

  // Data state
  const [forestAreas, setForestAreas] = createSignal<FeatureCollection>({ type: "FeatureCollection", features: [] });
  const [windData, setWindData] = createSignal<WindData>({ speed: 0, direction: 0 });

  // Fetch initial data and subscribe to updates
  onMount(() => {
    let ws: WebSocket | null = null;

    // Fetch initial data
    fetch('/api/watch')
      .then(res => res.json())
      .then(data => {
        setForestAreas(data);
        setWindData({ speed: 0, direction: 0 });
        //if (data.wind) setWindData(data.wind);
      });

    // Subscribe to updates
    ws = new WebSocket(`ws://${window.location.host}/api/ws`);
    ws.onmessage = (event) => {
      try {
        const data = JSON.parse(event.data);
        setForestAreas(data);
        //if (data.wind) setWindData(data.wind);
      } catch (e) {
        // Ignore malformed messages
      }
    };

    onCleanup(() => {
      ws?.close();
    });
  });

  const handleViewChange = (mode: ViewMode) => setViewMode(mode);

  return (
    <div class="dashboard">
      <Header viewMode={viewMode} onChange={handleViewChange} />
      <MapContainer
        viewMode={viewMode}
        areas={forestAreas}
        windData={windData()}
      >
        <InfoPanel viewMode={viewMode} />
        {/*<WindIndicator direction={windData().direction} speed={windData().speed} />*/}
      </MapContainer>
    </div>
  );
};

export default App;