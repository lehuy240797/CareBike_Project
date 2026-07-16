import React, { createContext, useContext, useEffect, useRef, useState } from 'react';
import type { ReactNode } from 'react';
import { Client } from '@stomp/stompjs';

interface WebSocketContextType {
  isConnected: boolean;
  subscribeToEvent: (eventType: string, callback: () => void) => void;
  unsubscribeFromEvent: (eventType: string, callback: () => void) => void;
}

const WebSocketContext = createContext<WebSocketContextType | undefined>(undefined);

interface WebSocketProviderProps {
  branchId?: number;
  children: ReactNode;
}

export const WebSocketProvider: React.FC<WebSocketProviderProps> = ({ branchId, children }) => {
  const [isConnected, setIsConnected] = useState(false);
  const clientRef = useRef<Client | null>(null);
  
  // A simple event emitter map
  const listenersRef = useRef<Record<string, (() => void)[]>>({});

  useEffect(() => {
    if (!branchId) return;

    const client = new Client({
      brokerURL: 'ws://localhost:8080/ws',
      reconnectDelay: 5000,
      onConnect: () => {
        console.log(`WebSocket connected for branch ${branchId}`);
        setIsConnected(true);

        // Subscribe to branch specific updates
        client.subscribe(`/topic/branches/${branchId}/updates`, (message) => {
          if (message.body) {
            try {
              const event = JSON.parse(message.body);
              const listeners = listenersRef.current[event.type] || [];
              listeners.forEach(cb => cb());
              
              // We could also show a toast for specific events if needed, but doing it in the component is better.
            } catch (e) {
              console.error("Error parsing websocket message", e);
            }
          }
        });

        // Subscribe to global updates
        client.subscribe(`/topic/global/updates`, (message) => {
          if (message.body) {
            try {
              const event = JSON.parse(message.body);
              const listeners = listenersRef.current[event.type] || [];
              listeners.forEach(cb => cb());
            } catch (e) {
              console.error("Error parsing websocket message", e);
            }
          }
        });
      },
      onDisconnect: () => {
        setIsConnected(false);
      },
      onWebSocketError: (error) => {
        console.error('WebSocket Error:', error);
      }
    });

    client.activate();
    clientRef.current = client;

    return () => {
      client.deactivate();
      clientRef.current = null;
    };
  }, [branchId]);

  const subscribeToEvent = (eventType: string, callback: () => void) => {
    if (!listenersRef.current[eventType]) {
      listenersRef.current[eventType] = [];
    }
    if (!listenersRef.current[eventType].includes(callback)) {
      listenersRef.current[eventType].push(callback);
    }
  };

  const unsubscribeFromEvent = (eventType: string, callback: () => void) => {
    if (listenersRef.current[eventType]) {
      listenersRef.current[eventType] = listenersRef.current[eventType].filter(cb => cb !== callback);
    }
  };

  return (
    <WebSocketContext.Provider value={{ isConnected, subscribeToEvent, unsubscribeFromEvent }}>
      {children}
    </WebSocketContext.Provider>
  );
};

export const useWebSocket = () => {
  const context = useContext(WebSocketContext);
  if (context === undefined) {
    throw new Error('useWebSocket must be used within a WebSocketProvider');
  }
  return context;
};

export const useWebSocketEvent = (eventType: string, callback: () => void) => {
  const { subscribeToEvent, unsubscribeFromEvent } = useWebSocket();

  useEffect(() => {
    subscribeToEvent(eventType, callback);
    return () => {
      unsubscribeFromEvent(eventType, callback);
    };
  }, [eventType, callback, subscribeToEvent, unsubscribeFromEvent]);
};
