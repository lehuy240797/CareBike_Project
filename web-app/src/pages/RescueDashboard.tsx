import React, { useState, useEffect, useCallback } from 'react';
import { AlertTriangle, CheckCircle, Clock } from 'lucide-react';
import { Client } from '@stomp/stompjs'; 
import toast from 'react-hot-toast'; 

import { useWebSocketEvent } from '../context/WebSocketContext';


// Interfaces unchanged
interface Vehicle { brand: string; model: string; licensePlate: string; }
interface Customer { fullName: string; phone: string; }
interface Rescue { id: number; customer: Customer; vehicle: Vehicle; latitude: number; longitude: number; issueDescription: string; status: string; staffCode?: string; assignedStaffName?: string; createdAt: string; }

// NOTE: component now receives props
interface RescueDashboardProps {
    branchId: number;
}

const RescueDashboard: React.FC<RescueDashboardProps> = ({ branchId }) => {
    const [rescues, setRescues] = useState<Rescue[]>([]);
    const [isLoading, setIsLoading] = useState(true);

    // 1. Function to load the existing list from the API
    const fetchRescues = useCallback(async () => {
        if (!branchId) return;
        setIsLoading(true);
        try {
            const response = await fetch(`http://localhost:8080/api/rescues/branch/${branchId}`);
            if (response.ok) {
                const data = await response.json();
                setRescues(data.filter((r: Rescue) => !['COMPLETED', 'CANCELLED'].includes(r.status)));
            }
        } catch (error) {
            console.error('Failed to load the rescue list:', error);
        } finally {
            setIsLoading(false);
        }
    }, [branchId]);

    useWebSocketEvent('RESCUE_UPDATED', fetchRescues);

    // 2. CONNECT WEBSOCKET TO LISTEN FOR NEW RESCUE CASES
    useEffect(() => {
        if (!branchId) return;

        void Promise.resolve().then(fetchRescues); // Initial data load

        const stompClient = new Client({
            brokerURL: 'ws://localhost:8080/ws',
            reconnectDelay: 5000,
        });

        stompClient.onConnect = () => {
            console.log('📡 Rescue radar enabled for branch:', branchId);

            // Subscribe to this branch's rescues channel
            stompClient.subscribe(`/topic/branches/${branchId}/rescues`, (message) => {
                if (message.body) {
                    const newRescue = JSON.parse(message.body);

                    // Push the new rescue case to the top of the on-screen list
                    setRescues(prev => [newRescue, ...prev.filter(r => r.id !== newRescue.id)]);

                    // Emergency alert via the toast notification system
                    toast.error(`🚨 ALERT: A customer just requested emergency roadside assistance!`, { duration: 5000 });
                }
            });
        };

        stompClient.activate();

        return () => {
            stompClient.deactivate();
        };
    }, [branchId, fetchRescues]); // Re-run when branchId changes

    /**
     * Handle confirming acceptance of a rescue case.
     */
    const handleAcceptRescue = async (rescueId: number) => {
        toast.success(`You have accepted rescue case #${rescueId}`);
        setRescues(prev => prev.filter(r => r.id !== rescueId));
    };

    if (isLoading) return <div className="p-8 text-center text-gray-500">Loading rescue data...</div>;

    return (
        <div className="bg-red-50 p-6 rounded-xl border border-red-200 shadow-sm">
            <div className="mb-4 flex justify-between items-center">
                <div>
                    <h2 className="text-xl font-bold text-red-700 flex items-center gap-2">
                        <AlertTriangle className="animate-pulse" size={24} />
                        EMERGENCY RESCUE DISPATCH
                    </h2>
                    <p className="text-red-500 text-sm mt-1">Active rescue requests and assignments</p>
                </div>
                <button onClick={() => { void fetchRescues(); }} className="bg-white border border-red-200 text-red-600 px-3 py-1.5 rounded-lg hover:bg-red-100 flex items-center gap-2 text-sm shadow-sm transition">
                    <Clock size={14} /> Refresh
                </button>
            </div>

            {rescues.length === 0 ? (
                <div className="bg-white p-8 rounded-lg border border-dashed border-red-200 text-center text-gray-500">
                    <CheckCircle className="mx-auto text-green-400 mb-2" size={32} />
                    <p>All clear. No customers currently in trouble.</p>
                </div>
            ) : (
                <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
                    {rescues.map((rescue) => (
                        <div key={rescue.id} className="bg-white rounded-lg p-4 shadow-md border-l-4 border-red-500 relative">
                            <div className="flex items-start justify-between mb-2">
                                <h3 className="font-bold text-gray-800">Request #{rescue.id}</h3>
                            </div>

                            <div className="text-sm text-gray-600 space-y-1 mb-3">
                                <p><span className="font-semibold text-gray-800">Customer:</span> {rescue.customer?.fullName}</p>
                                {rescue.staffCode && <p><span className="font-semibold text-gray-800">Assigned staff:</span> {rescue.assignedStaffName ? `${rescue.assignedStaffName} (${rescue.staffCode})` : rescue.staffCode}</p>}
                                <p><span className="font-semibold text-gray-800">Status:</span> {rescue.status}</p>
                                <p className="text-red-600 bg-red-50 p-1.5 rounded border border-red-100">⚠️ {rescue.issueDescription}</p>
                                <div className="bg-gray-100 p-2 rounded mt-2">
                                    <p className="font-medium text-gray-800">🚙 {rescue.vehicle?.brand} {rescue.vehicle?.model}</p>
                                    <p>Plate: <strong className="text-black">{rescue.vehicle?.licensePlate}</strong></p>
                                </div>
                            </div>

                            <div className="flex gap-2">
                                <a href={`tel:${rescue.customer?.phone}`} className="flex-1 bg-green-500 text-white text-center py-2 rounded text-sm font-semibold hover:bg-green-600">📞 Call</a>
                                <a href={`https://www.google.com/maps/dir/?api=1&...${rescue.latitude},${rescue.longitude}`} target="_blank" rel="noreferrer" className="flex-1 bg-blue-500 text-white text-center py-2 rounded text-sm font-semibold hover:bg-blue-600">🗺️ Directions</a>
                            </div>
                            {rescue.status === 'PENDING' && (
                            <button onClick={() => handleAcceptRescue(rescue.id)} className="w-full mt-2 bg-red-600 text-white py-2 rounded text-sm font-bold uppercase hover:bg-red-700">✅ Accept</button>
                            )}
                        </div>
                    ))}
                </div>
            )}
        </div>
    );
};

export default RescueDashboard;
