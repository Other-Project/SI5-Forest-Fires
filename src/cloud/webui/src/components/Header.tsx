import { type Component, type Accessor } from 'solid-js';
import type { ViewMode } from '../types';
import './header.css';

const Header: Component<{ viewMode: Accessor<ViewMode>; onChange: (m: ViewMode) => void }> = (props) => {
  return (
    <header class="header">
      <div class="logo-title">
        {/*<img src="/icon.svg" alt="Logo" class="logo" height="15" />
        <h1>Forest Dashboard</h1>*/}
      </div>
      <div class="view-selector">
        <button
          class={props.viewMode() === 'risk' ? 'active' : ''}
          onClick={() => props.onChange('risk')}
        >
          Risk
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
