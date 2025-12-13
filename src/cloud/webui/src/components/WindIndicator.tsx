import { type Component } from 'solid-js';
import './wind-indicator.css';

const toCardinal = (deg: number) => {
  const dirs = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW', 'N'];
  return dirs[Math.round(((deg % 360) / 45))];
};

const WindIndicator: Component<{ direction: number; speed: number }> = (props) => {
  return (
    <div class="wind-indicator">
      <div class="wind-arrow" style={{ transform: `rotate(${props.direction}deg)` }}>
        ↑
      </div>
      <span class="wind-speed">{props.speed} mph {toCardinal(props.direction)}</span>
    </div>
  );
};

export default WindIndicator;

