import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import './firebaseSetup';
import './styles/variables.css';
import './styles/auth.css';
import './styles/app.css';
import './index.css';
import 'leaflet/dist/leaflet.css';
import App from './App.tsx';

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <App />
  </StrictMode>,
);
