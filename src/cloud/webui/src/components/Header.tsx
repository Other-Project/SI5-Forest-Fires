import { type Component, type Accessor } from 'solid-js';
import type { ViewMode } from '../types';
import './header.css';

const Header: Component<{ viewMode: Accessor<ViewMode>; onChange: (m: ViewMode) => void }> = (props) => {
  return (
    <header class="header">
      <h1>Forest Fire Monitoring Dashboard</h1>
      <div class="view-selector">
        <button
          class={props.viewMode() === 'risk' ? 'active' : ''}
          onClick={() => props.onChange('risk')}
        >
          Fire Risk
        </button>
        <button
          class={props.viewMode() === 'surveillance' ? 'active' : ''}
          onClick={() => props.onChange('surveillance')}
        >
          Surveillance
        </button>
      </div>
    </header>
  );
};

export default Header;
