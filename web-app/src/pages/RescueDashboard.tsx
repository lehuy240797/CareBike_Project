import React, { useState, useEffect } from 'react';
import { AlertTriangle, MapPin, Phone, CheckCircle, Clock } from 'lucide-react';
import { Client } from '@stomp/stompjs'; 
import toast from 'react-hot-toast'; 



// Các interface giữ nguyên
interface Vehicle { brand: string; model: string; licensePlate: string; }
interface Customer { fullName: string; phone: string; }
interface Rescue { id: number; customer: Customer; vehicle: Vehicle; latitude: number; longitude: number; issueDescription: string; status: string; createdAt: string; }

// CHÚ Ý: Chuyển component thành dạng nhận Props
interface RescueDashboardProps {
    branchId: number;
}

const RescueDashboard: React.FC<RescueDashboardProps> = ({ branchId }) => {
    const [rescues, setRescues] = useState<Rescue[]>([]);
    const [isLoading, setIsLoading] = useState(true);

    // 1. Hàm gọi API tải danh sách cũ
    const fetchRescues = async () => {
        if (!branchId) return;
        setIsLoading(true);
        try {
            const response = await fetch(`http://localhost:8080/api/rescues/branch/${branchId}`);
            if (response.ok) {
                const data = await response.json();
                setRescues(data.filter((r: Rescue) => r.status === 'PENDING'));
            }
        } catch (error) {
            console.error('Lỗi tải danh sách cứu hộ:', error);
        } finally {
            setIsLoading(false);
        }
    };

    // 2. KẾT NỐI WEBSOCKET LẮNG NGHE CA CỨU HỘ MỚI
    useEffect(() => {
        if (!branchId) return;

        fetchRescues(); // Load dữ liệu lần đầu

        const stompClient = new Client({
            brokerURL: 'ws://localhost:8080/ws',
            reconnectDelay: 5000,
        });

        stompClient.onConnect = () => {
            console.log('📡 Đã bật Radar Cứu Hộ cho Chi nhánh:', branchId);

            // Lắng nghe đúng kênh rescues của chi nhánh này
            stompClient.subscribe(`/topic/branches/${branchId}/rescues`, (message) => {
                if (message.body) {
                    const newRescue = JSON.parse(message.body);

                    // Đẩy ca cứu hộ mới lên đầu danh sách màn hình
                    setRescues(prev => [newRescue, ...prev]);

                    // Cảnh báo khẩn cấp thông qua hệ thống thông báo Toast
                    toast.error(`🚨 BÁO ĐỘNG: Có khách hàng vừa yêu cầu cứu hộ khẩn cấp!`, { duration: 5000 });
                }
            });
        };

        stompClient.activate();

        return () => {
            stompClient.deactivate();
        };
    }, [branchId]); // Chạy lại khi branchId thay đổi

    /**
     * Xử lý xác nhận tiếp nhận ca cứu hộ từ hệ thống.
     */
    const handleAcceptRescue = async (rescueId: number) => {
        toast.success(`Bạn đã tiếp nhận ca cứu hộ #${rescueId}`);
        setRescues(prev => prev.filter(r => r.id !== rescueId));
    };

    if (isLoading) return <div className="p-8 text-center text-gray-500">Đang tải dữ liệu cứu hộ...</div>;

    return (
        <div className="bg-red-50 p-6 rounded-xl border border-red-200 shadow-sm">
            <div className="mb-4 flex justify-between items-center">
                <div>
                    <h2 className="text-xl font-bold text-red-700 flex items-center gap-2">
                        <AlertTriangle className="animate-pulse" size={24} />
                        ĐIỀU PHỐI CỨU HỘ KHẨN CẤP
                    </h2>
                    <p className="text-red-500 text-sm mt-1">Các yêu cầu đang chờ xuất phát</p>
                </div>
                <button onClick={fetchRescues} className="bg-white border border-red-200 text-red-600 px-3 py-1.5 rounded-lg hover:bg-red-100 flex items-center gap-2 text-sm shadow-sm transition">
                    <Clock size={14} /> Cập nhật
                </button>
            </div>

            {rescues.length === 0 ? (
                <div className="bg-white p-8 rounded-lg border border-dashed border-red-200 text-center text-gray-500">
                    <CheckCircle className="mx-auto text-green-400 mb-2" size={32} />
                    <p>Khu vực an toàn. Không có khách hàng nào đang gặp sự cố.</p>
                </div>
            ) : (
                <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
                    {rescues.map((rescue) => (
                        <div key={rescue.id} className="bg-white rounded-lg p-4 shadow-md border-l-4 border-red-500 relative">
                            <div className="flex items-start justify-between mb-2">
                                <h3 className="font-bold text-gray-800">Yêu cầu #{rescue.id}</h3>
                            </div>

                            <div className="text-sm text-gray-600 space-y-1 mb-3">
                                <p><span className="font-semibold text-gray-800">Khách:</span> {rescue.customer?.fullName}</p>
                                <p className="text-red-600 bg-red-50 p-1.5 rounded border border-red-100">⚠️ {rescue.issueDescription}</p>
                                <div className="bg-gray-100 p-2 rounded mt-2">
                                    <p className="font-medium text-gray-800">🚙 {rescue.vehicle?.brand} {rescue.vehicle?.model}</p>
                                    <p>Biển số: <strong className="text-black">{rescue.vehicle?.licensePlate}</strong></p>
                                </div>
                            </div>

                            <div className="flex gap-2">
                                <a href={`tel:${rescue.customer?.phone}`} className="flex-1 bg-green-500 text-white text-center py-2 rounded text-sm font-semibold hover:bg-green-600">📞 Gọi</a>
                                <a href={`https://www.google.com/maps/dir/?api=1&...${rescue.latitude},${rescue.longitude}`} target="_blank" rel="noreferrer" className="flex-1 bg-blue-500 text-white text-center py-2 rounded text-sm font-semibold hover:bg-blue-600">🗺️ Dẫn đường</a>
                            </div>
                            <button onClick={() => handleAcceptRescue(rescue.id)} className="w-full mt-2 bg-red-600 text-white py-2 rounded text-sm font-bold uppercase hover:bg-red-700">✅ Nhận Ca</button>
                        </div>
                    ))}
                </div>
            )}
        </div>
    );
};

export default RescueDashboard;