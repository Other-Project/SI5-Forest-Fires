import { type Component, createSignal, onMount, createEffect, type JSXElement } from 'solid-js';
import maplibregl from 'maplibre-gl';
import { Deck } from '@deck.gl/core';
import { TerrainLayer } from '@deck.gl/geo-layers';
import { ScatterplotLayer } from '@deck.gl/layers';
import 'maplibre-gl/dist/maplibre-gl.css';
import type { ViewMode, FirePoint, WindData } from '../types';
import './map-container.css';

type MapContainerProps = {
  viewMode: () => ViewMode;
  firePoints: FirePoint[];
  windData: WindData[];
  children?: JSXElement;
};

const MapContainer: Component<MapContainerProps> = (props) => {
  const [map, setMap] = createSignal<maplibregl.Map | null>(null);
  const [deck, setDeck] = createSignal<Deck | null>(null);

  const createLayers = () => {
    const currentView = props.viewMode();

    const layers: any[] = [
      new TerrainLayer({
        id: 'terrain',
        elevationData: 'https://s3.amazonaws.com/elevation-tiles-prod/terrarium/{z}/{x}/{y}.png',
        elevationDecoder: { rScaler: 256, gScaler: 1, bScaler: 1 / 256, offset: -32768 },
        texture: 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
        wireframe: false,
        color: [255, 255, 255],
      }),
    ];

    if (currentView === 'risk') {
      layers.push(
        new ScatterplotLayer({
          id: 'fire-risk-points',
          data: props.firePoints,
          getPosition: (d: FirePoint) => [...d.coordinates, 500],
          getRadius: (d: FirePoint) => d.intensity * 1000,
          getFillColor: (d: FirePoint) => {
            if (d.status === 'active') return [255, 0, 0, 180];
            if (d.status === 'contained') return [255, 165, 0, 150];
            return [255, 255, 0, 120];
          },
          radiusMinPixels: 8,
          radiusMaxPixels: 100,
        })
      );
    } else {
      layers.push(
        new ScatterplotLayer({
          id: 'surveillance-points',
          data: props.firePoints,
          getPosition: (d: FirePoint) => [...d.coordinates, 500],
          getRadius: 1500,
          getFillColor: [0, 150, 255, 150],
          radiusMinPixels: 10,
        })
      );
    }

    return layers;
  };

  onMount(() => {
    const mapInstance = new maplibregl.Map({
      container: 'map',
      style: 'https://basemaps.cartocdn.com/gl/dark-matter-gl-style/style.json',
      center: [-122.4, 37.8],
      zoom: 10,
      pitch: 60,
      bearing: 0,
    });

    mapInstance.on('load', () => {
      setMap(mapInstance);

      const deckInstance = new Deck({
        canvas: 'deck-canvas',
        width: '100%',
        height: '100%',
        initialViewState: {
          longitude: -122.4,
          latitude: 37.8,
          zoom: 10,
          pitch: 60,
          bearing: 0,
        },
        controller: true,
        onViewStateChange: ({ viewState }) => {
          mapInstance.jumpTo({
            center: [viewState.longitude, viewState.latitude],
            zoom: viewState.zoom,
            bearing: viewState.bearing,
            pitch: viewState.pitch,
          });
        },
        layers: createLayers(),
      });

      setDeck(deckInstance);
    });
  });

  // update layers when mode changes
  createEffect(() => {
    props.viewMode();
    const deckInstance = deck();
    if (deckInstance) {
      deckInstance.setProps({ layers: createLayers() });
    }
  });

  return (
    <div class="map-container">
      <div id="map" />
      <canvas id="deck-canvas" />
      {props.children}
    </div>
  );
};

export default MapContainer;
