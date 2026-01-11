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
    let reconnectAttempts = 0;
    let reconnectTimer: number | null = null;
    let pingIntervalId: number | null = null;
    let pongTimeoutId: number | null = null;

    const pingIntervalMs = 15000; // send ping every 15s
    const pongTimeoutMs = 5000; // expect pong within 5s
    const maxReconnectDelay = 30000; // cap backoff at 30s

    function wsUrl() {
      const proto = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
      return `${proto}//${window.location.host}/api/ws`;
    }

    function clearReconnectTimer() {
      if (reconnectTimer) {
        clearTimeout(reconnectTimer);
        reconnectTimer = null;
      }
    }

    function scheduleReconnect() {
      reconnectAttempts++;
      const delay = Math.min(1000 * Math.pow(2, reconnectAttempts - 1), maxReconnectDelay);
      reconnectTimer = window.setTimeout(() => initializeWebSocket(), delay);
    }

    function startHeartbeat() {
      // send pings periodically and expect a pong
      if (pingIntervalId) return;
      pingIntervalId = window.setInterval(() => {
        if (!ws || ws.readyState !== WebSocket.OPEN) return;
        try {
          ws.send(JSON.stringify({ type: 'ping', ts: Date.now() }));
          // set pong timeout
          if (pongTimeoutId) clearTimeout(pongTimeoutId);
          pongTimeoutId = window.setTimeout(() => {
            // no pong -> close to trigger reconnect
            try { ws?.close(); } catch (e) {}
          }, pongTimeoutMs);
        } catch (e) {
          // ignore send errors
        }
      }, pingIntervalMs);
    }

    function stopHeartbeat() {
      if (pingIntervalId) {
        clearInterval(pingIntervalId);
        pingIntervalId = null;
      }
      if (pongTimeoutId) {
        clearTimeout(pongTimeoutId);
        pongTimeoutId = null;
      }
    }

    async function retrieveForestData() {
      try {
        const res = await fetch('/api/watch');
        if (!res.ok) return;
        const data = await res.json();
        setForestAreas(data);
        setWindData({ speed: 0, direction: 0 }); // TODO
      } catch {
        // ignore fetch errors
      }
    }

    function initializeWebSocket() {
      clearReconnectTimer();
      try {
        ws = new WebSocket(wsUrl());
      } catch (e) {
        scheduleReconnect();
        return;
      }

      ws.onopen = () => {
        const wasReconnect = reconnectAttempts > 0;
        reconnectAttempts = 0;
        startHeartbeat();

        if (wasReconnect) retrieveForestData();
      };

      ws.onmessage = (event) => {
        try {
          const data = JSON.parse(event.data);
          // handle pong
          if (data && data.type === 'pong') {
            if (pongTimeoutId) {
              clearTimeout(pongTimeoutId);
              pongTimeoutId = null;
            }
            return;
          }

          // handle structured messages if your server uses wrappers
          if (data && data.message_type === 'areas' && data.payload) {
            setForestAreas(data.payload);
            return;
          }
          if (data && data.message_type === 'wind' && data.payload) {
            setWindData({ speed: data.payload.speed ?? 0, direction: data.payload.direction ?? 0 });
            return;
          }

          // fallback: assume payload is a FeatureCollection or raw update
          setForestAreas(data);
        } catch (e) {
          // Ignore malformed messages
        }
      };

      ws.onclose = () => {
        stopHeartbeat();
        ws = null;
        scheduleReconnect();
      };

      ws.onerror = () => {
        // onerror -> let onclose handle reconnect/backoff
      };
    }

    retrieveForestData();
    initializeWebSocket();

    onCleanup(() => {
      clearReconnectTimer();
      stopHeartbeat();
      try { ws?.close(); } catch (e) {}
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