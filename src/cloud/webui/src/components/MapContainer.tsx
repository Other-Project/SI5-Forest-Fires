import { type Component, createSignal, onMount, createEffect, type JSXElement } from 'solid-js';
import maplibregl from 'maplibre-gl';
import { MapboxOverlay } from '@deck.gl/mapbox';
import 'maplibre-gl/dist/maplibre-gl.css';
import type { ViewMode, WindData } from '../types';
import './map-container.css';
import type { LayersList } from '@deck.gl/core';
import { ParticleLayer } from 'weatherlayers-gl';
import type { FeatureCollection } from 'geojson';

const DEM_TILE_URL = 'https://s3.amazonaws.com/elevation-tiles-prod/terrarium/{z}/{x}/{y}.png'; // terrarium tiles (no key)

type MapContainerProps = {
    viewMode: () => ViewMode;
    windData: WindData;
    areas: () => FeatureCollection;
    children?: JSXElement;
};

/**
 * Generates a synthetic Float32Array representing a uniform vector field.
 * 
 * @param u - Zonal velocity (m/s). Positive = West to East.
 * @param v - Meridional velocity (m/s). Positive = South to North.
 * @returns TextureData object compatible with WeatherLayers.
 */
function createUniformWindData(u: number, v: number) {
    // We utilize a minimal 2x2 grid. 
    // This is sufficient for a mathematically uniform field as interpolation
    // between identical values yields the constant value.
    const width = 2;
    const height = 2;

    // 2 channels (u, v) per pixel
    const channels = 2;
    const size = width * height * channels;
    const data = new Float32Array(size);

    for (let i = 0; i < size; i += channels) {
        data[i] = u;
        data[i + 1] = v;
    }

    return {
        data: data,
        width: width,
        height: height
    };
}


const MapContainer: Component<MapContainerProps> = (props) => {
    // keep both getter and setter so we can read the map instance later
    const [map, setMap] = createSignal<maplibregl.Map | null>(null);
    const [overlay, setOverlay] = createSignal<MapboxOverlay | null>(null);

    const createLayers = () => {
        const currentView = props.viewMode();

        const layers: LayersList = [];

        if (currentView === 'risk') {
            // TODO
        } else if (currentView === 'surveillance') {
            // TODO
        }

        const [wind_u, wind_v] = props.windData ? [
            props.windData.speed * Math.cos((props.windData.direction * Math.PI) / 180),
            props.windData.speed * Math.sin((props.windData.direction * Math.PI) / 180)
        ] : [0, 0];

        layers.push(new ParticleLayer({
            id: 'wind-layer',
            image: createUniformWindData(wind_u, wind_v),
            imageType: 'VECTOR', // data is (u,v) vectors
            bounds: [4.5, 43, 8, 45], // [minLon, minLat, maxLon, maxLat]
            numParticles: 2048,
            maxAge: 40,
            speedFactor: 10,
            width: 2,
            color: [50, 50, 50, 50],
            imageInterpolation: 'LINEAR'
        }));


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

            mapInstance.addSource('risk-areas', {
                type: 'geojson',
                data: props.areas()
            });

            // Filled polygons colored by 'risk' feature property.
            mapInstance.addLayer({
                id: 'risk-areas-fill',
                type: 'fill',
                source: 'risk-areas',
                paint: {
                    'fill-color': [
                        'interpolate',
                        ['linear'],
                        ['coalesce', ['to-number', ['get', 'risk']], 0],
                        0, '#10b981',
                        50, '#eab308',
                        100, '#ef4444'
                    ],
                    'fill-opacity': 0.4,
                }
            });

            // Outline for the polygons
            mapInstance.addLayer({
                id: 'risk-areas-outline',
                type: 'line',
                source: 'risk-areas',
                paint: {
                    'line-color': '#000000',
                    'line-opacity': 0.2,
                    'line-width': 1
                }
            });

            // Add labels showing the risk percentage inside each polygon.
            // FIXME: Duplicates the label when polygons are across multiple tiles
            mapInstance.addLayer({
                id: 'risk-areas-label',
                type: 'symbol',
                source: 'risk-areas',
                layout: {
                    'text-field': [
                        'concat',
                        ['to-string', ['round', ['coalesce', ['to-number', ['get', 'risk']], 0]]],
                        '%'
                    ],
                    'text-font': ['Open Sans Bold', 'Arial Unicode MS Bold'],
                    'text-size': 12,
                    'text-anchor': 'center',
                    'text-allow-overlap': true,
                    'text-ignore-placement': true,
                    'symbol-placement': 'point' // place at polygon centroid
                },
                paint: {
                    'text-color': '#000000',
                    'text-halo-color': '#ffffff',
                    'text-halo-width': 1,
                    'text-opacity': 0.7
                },
                minzoom: 10
            });

            // Initially hide the risk layers unless the viewMode is 'risk'
            const initialVisibility = props.viewMode() === 'risk' ? 'visible' : 'none';
            mapInstance.setLayoutProperty('risk-areas-fill', 'visibility', initialVisibility);
            mapInstance.setLayoutProperty('risk-areas-outline', 'visibility', initialVisibility);
            mapInstance.setLayoutProperty('risk-areas-label', 'visibility', initialVisibility);

            // Use MapboxOverlay so deck.gl layers are attached to the map and map drives the view
            const overlayInstance = new MapboxOverlay({
                layers: createLayers()
            });
            mapInstance.addControl(overlayInstance);
            setOverlay(overlayInstance);
        });
    });

    // update the geojson source data and layer visibility reactively
    createEffect(() => {
        const m = map();
        if (!m) return;

        const src = m.getSource('risk-areas') as maplibregl.GeoJSONSource | undefined;
        src?.setData(props.areas());

        // Force a repaint to ensure MapLibre redraws the updated GeoJSON
        m.triggerRepaint?.();

        // Also refresh deck.gl overlay props to provoke any overlay-driven redraws
        const ov = overlay();
        if (ov) ov.setProps({ layers: createLayers() });

        // toggle visibility depending on view mode
        const visibility = props.viewMode() === 'risk' ? 'visible' : 'none';
        if (m.getLayer('risk-areas-fill')) m.setLayoutProperty('risk-areas-fill', 'visibility', visibility);
        if (m.getLayer('risk-areas-outline')) m.setLayoutProperty('risk-areas-outline', 'visibility', visibility);
        if (m.getLayer('risk-areas-label')) m.setLayoutProperty('risk-areas-label', 'visibility', visibility);
    });

    // update layers when mode changes
    createEffect(() => {
        props.viewMode();
        const ov = overlay();
        if (ov) ov.setProps({ layers: createLayers() });
    });

    return (
        <div class="map-container">
            <div id="map" />
            <canvas id="deck-canvas" />
            <div id="panels">{props.children}</div>
        </div>
    );
};

export default MapContainer;
