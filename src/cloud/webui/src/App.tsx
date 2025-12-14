// src/App.tsx
import { type Component, createSignal } from 'solid-js';
import './App.css'
import Header from './components/Header';
import InfoPanel from './components/InfoPanel';
import MapContainer from './components/MapContainer';
import type { ViewMode, WindData } from './types';
import type { FeatureCollection } from 'geojson';

const App: Component = () => {
  const [viewMode, setViewMode] = createSignal<ViewMode>('risk');

  // Sample data
  const forestAreas: FeatureCollection = {
    "type": "FeatureCollection",
    "features": [
      {
        "type": "Feature",
        "properties": {
          "risk": 30
        },
        "geometry": {
          "coordinates": [
            [
              [
                5.5,
                43.5
              ],
              [
                5.55,
                43.5
              ],
              [
                5.55,
                43.55
              ],
              [
                5.5,
                43.55
              ],
              [
                5.5,
                43.5
              ]
            ]
          ],
          "type": "Polygon"
        }
      },
      {
        "type": "Feature",
        "properties": {
          "risk": 75
        },
        "geometry": {
          "coordinates": [
            [
              [
                5.55,
                43.55
              ],
              [
                5.6,
                43.55
              ],
              [
                5.6,
                43.6
              ],
              [
                5.55,
                43.6
              ],
              [
                5.55,
                43.55
              ]
            ]
          ],
          "type": "Polygon"
        }
      },
      {
        "type": "Feature",
        "properties": {
          "risk": 100
        },
        "geometry": {
          "coordinates": [
            [
              [
                5.55,
                43.55
              ],
              [
                5.55,
                43.5
              ],
              [
                5.6,
                43.5
              ],
              [
                5.6,
                43.55
              ],
              [
                5.55,
                43.55
              ]
            ]
          ],
          "type": "Polygon"
        }
      },
      {
        "type": "Feature",
        "properties": {
          "risk": 10
        },
        "geometry": {
          "coordinates": [
            [
              [
                5.55,
                43.55
              ],
              [
                5.55,
                43.6
              ],
              [
                5.5,
                43.6
              ],
              [
                5.5,
                43.55
              ],
              [
                5.55,
                43.55
              ]
            ]
          ],
          "type": "Polygon"
        }
      }
    ]
  };
  const windData: WindData = { speed: 15, direction: 45 };

  const handleViewChange = (mode: ViewMode) => setViewMode(mode);

  return (
    <div class="dashboard">
      <Header viewMode={viewMode} onChange={handleViewChange} />
      <MapContainer viewMode={viewMode} areas={forestAreas} windData={windData}>
        <InfoPanel viewMode={viewMode} />
        {/*<WindIndicator direction={windData.direction} speed={windData.speed} />*/}
      </MapContainer>
    </div>
  );
};

export default App;