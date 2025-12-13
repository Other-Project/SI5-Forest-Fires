import { type Component, Show, type Accessor } from 'solid-js';
import type { ViewMode } from '../types';
import './info-panel.css';

const InfoPanel: Component<{ viewMode: Accessor<ViewMode> }> = (props) => {
  return (
    <div class="info-panel">
      <Show when={props.viewMode() === 'risk'}>
        <div class="panel-content">
          <h3>Active Fire Risk Zones</h3>
          <div class="stats">
            <div class="stat">
              <span class="label">High Risk:</span>
              <span class="value red">3</span>
            </div>
            <div class="stat">
              <span class="label">Wind Speed:</span>
              <span class="value">15 mph</span>
            </div>
            <div class="stat">
              <span class="label">Humidity:</span>
              <span class="value">32%</span>
            </div>
          </div>
          <div class="legend">
            <div class="legend-item">
              <span class="dot red"></span>
              <span>Active Fire</span>
            </div>
            <div class="legend-item">
              <span class="dot orange"></span>
              <span>Contained</span>
            </div>
            <div class="legend-item">
              <span class="dot yellow"></span>
              <span>Monitoring</span>
            </div>
          </div>
        </div>
      </Show>

      <Show when={props.viewMode() === 'surveillance'}>
        <div class="panel-content">
          <h3>Surveillance Coverage</h3>
          <div class="stats">
            <div class="stat">
              <span class="label">Cameras:</span>
              <span class="value">12</span>
            </div>
            <div class="stat">
              <span class="label">Sensors:</span>
              <span class="value">24</span>
            </div>
            <div class="stat">
              <span class="label">Coverage:</span>
              <span class="value">87%</span>
            </div>
          </div>
        </div>
      </Show>
    </div>
  );
};

export default InfoPanel;
