import { type Component, createSignal, onMount, createEffect, type JSXElement } from 'solid-js';
import maplibregl from 'maplibre-gl';
import { Deck } from '@deck.gl/core';
import { ScatterplotLayer } from '@deck.gl/layers';
import 'maplibre-gl/dist/maplibre-gl.css';
import type { ViewMode, FirePoint, WindData } from '../types';
import './map-container.css';

const DEM_TILE_URL = 'https://s3.amazonaws.com/elevation-tiles-prod/terrarium/{z}/{x}/{y}.png'; // terrarium tiles (no key)

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

        ];

        if (currentView === 'risk') {
            layers.push(
                new ScatterplotLayer({
                    id: 'fire-risk-points',
                    data: props.firePoints,
                    // position: légèrement au-dessus du terrain pour éviter inter-pénétrations et pics
                    getPosition: (d: FirePoint) => [...d.coordinates, (d.intensity ?? 1) * 10],
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
                    getPosition: (d: FirePoint) => [...d.coordinates, (d.intensity ?? 1) * 5],
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
            style: 'https://basemaps.cartocdn.com/gl/voyager-gl-style/style.json', // https://github.com/CartoDB/basemap-styles
            center: [5.58586, 43.60215],
            zoom: 10,
            pitch: 60,
            bearing: 0,
        });

        mapInstance.on('load', () => {
            setMap(mapInstance);

            // Add DEM source for terrain elevation
            mapInstance.addSource('dem-source', {
                type: 'raster-dem',
                tiles: [DEM_TILE_URL],
                tileSize: 256,
                encoding: 'terrarium'
            });

            // Set the terrain using the DEM source
            mapInstance.setTerrain({ source: 'dem-source', exaggeration: 1.5 });

            // Hillshade layer for better terrain visualization
            mapInstance.addLayer({
                id: 'hillshade-layer',
                type: 'hillshade',
                source: 'dem-source',
                maxzoom: 15,
                paint: {
                    'hillshade-shadow-color': '#000000',
                    'hillshade-highlight-color': '#ffffff',
                    'hillshade-accent-color': '#6b6b6b',
                    'hillshade-exaggeration': 0.1
                }
            });

            // Initialize Deck.gl
            const deckInstance = new Deck({
                canvas: 'deck-canvas',
                width: '100%',
                height: '100%',
                initialViewState: {
                    longitude: 5.58586,
                    latitude: 43.60215,
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
