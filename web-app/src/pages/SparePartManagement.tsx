import React, { useState, useEffect } from 'react';
import { Plus, Edit, Trash2, Package, Search } from 'lucide-react';
import toast from 'react-hot-toast';
import SparePartModal from '../components/modals/SparePartModal';
import apiClient from '../services/apiClient';

// Định nghĩa kiểu dữ liệu khớp với DB
export interface SparePart {
    id: number;
    name: string;
    price: number;
    description: string;
    imageUrl: string | null;
    categoryId?: number;
    categoryName?: string;
}

const SparePartManagement: React.FC = () => {
    const [spareParts, setSpareParts] = useState<SparePart[]>([]);
    const [searchTerm, setSearchTerm] = useState('');
    const [isModalOpen, setIsModalOpen] = useState(false);
    const [selectedPart, setSelectedPart] = useState<SparePart | null>(null);

    useEffect(() => {
        fetchSpareParts();
    }, []);

    const fetchSpareParts = async () => {
        try {
            const response = await apiClient.get('/spare-parts');
            if (response.status === 200) {
                setSpareParts(response.data); // Đổ dữ liệu thật vào bảng
            } else {
                toast.error('Lỗi khi tải dữ liệu phụ tùng!');
            }
        } catch (error) {
            console.error("Connection error:", error);
            toast.error('Unable to connect to server!');
        }
    };

    const handleOpenModal = (part?: SparePart) => {
        setSelectedPart(part || null);
        setIsModalOpen(true);
    };

    const handleCloseModal = () => {
        setIsModalOpen(false);
        setSelectedPart(null);
    };

    // GỌI API XÓA PHỤ TÙNG
    const handleDelete = async (id: number) => {
        if (window.confirm('Are you sure you want to delete this spare part?')) {
            try {
                const response = await apiClient.delete(`/spare-parts/${id}`);

                if (response.status === 204 || response.status === 200) {
                    toast.success('Spare part deleted successfully!');
                    fetchSpareParts(); // Tải lại danh sách sau khi xóa
                } else {
                    toast.error('Error deleting from server!');
                }
            } catch (error) {
                toast.error('Error connecting to server!');
            }
        }
    };

    const filteredParts = spareParts.filter(part =>
        part.name.toLowerCase().includes(searchTerm.toLowerCase()) ||
        (part.description && part.description.toLowerCase().includes(searchTerm.toLowerCase()))
    );

    return (
        <div className="p-6 bg-gray-50 min-h-screen">
            <div className="bg-white rounded-2xl shadow-sm p-6 mb-6 flex flex-col md:flex-row justify-between items-center gap-4 border border-gray-100">
                <div className="flex items-center gap-3">
                    <div className="p-3 bg-blue-50 text-blue-600 rounded-xl">
                        <Package size={28} />
                    </div>
                    <div>
                        <h1 className="text-2xl font-bold text-gray-800 m-0">Spare Parts</h1>
                        <p className="text-sm text-gray-500">Manage inventory and prices</p>
                    </div>
                </div>

                <div className="flex flex-col sm:flex-row gap-3 w-full md:w-auto">
                    <div className="relative w-full sm:w-64">
                        <div className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
                            <Search size={18} className="text-gray-400" />
                        </div>
                        <input
                            type="text"
                            placeholder="Search spare parts..."
                            value={searchTerm}
                            onChange={(e) => setSearchTerm(e.target.value)}
                            className="block w-full pl-10 pr-3 py-2 border border-gray-200 rounded-xl leading-5 bg-gray-50 focus:outline-none focus:bg-white focus:ring-2 focus:ring-blue-500 focus:border-blue-500 transition-colors sm:text-sm"
                        />
                    </div>
                    <button
                        onClick={() => handleOpenModal()}
                        className="flex items-center justify-center gap-2 px-5 py-2 bg-blue-600 hover:bg-blue-700 text-white font-medium rounded-xl transition-all shadow-sm hover:shadow-md"
                    >
                        <Plus size={18} /> Add New
                    </button>
                </div>
            </div>

            <div className="bg-white rounded-2xl shadow-sm border border-gray-100 overflow-hidden">
                <div className="overflow-x-auto">
                    <table className="w-full text-left border-collapse whitespace-nowrap">
                        <thead>
                            <tr className="bg-gray-50/50 border-b border-gray-100 text-gray-500 text-sm font-semibold uppercase tracking-wider">
                                <th className="px-6 py-4">ID</th>
                                <th className="px-6 py-4">Product</th>
                                <th className="px-6 py-4">Price</th>
                                <th className="px-6 py-4">Description</th>
                                <th className="px-6 py-4">Category</th>
                                <th className="px-6 py-4 text-center">Actions</th>
                            </tr>
                        </thead>
                        <tbody className="divide-y divide-gray-100">
                            {filteredParts.map((part) => (
                                <tr key={part.id} className="hover:bg-blue-50/50 transition-colors group">
                                    <td className="px-6 py-4 text-sm text-gray-500 font-medium">#{part.id}</td>
                                    <td className="px-6 py-4">
                                        <div className="flex items-center gap-4">
                                            {part.imageUrl ? (
                                                <div className="h-16 w-16 rounded-xl border border-gray-100 overflow-hidden bg-white shadow-sm flex-shrink-0">
                                                    <img src={part.imageUrl} alt={part.name} className="h-full w-full object-cover" />
                                                </div>
                                            ) : (
                                                <div className="h-16 w-16 rounded-xl bg-gray-50 border border-gray-100 flex items-center justify-center flex-shrink-0">
                                                    <Package size={24} className="text-gray-300" />
                                                </div>
                                            )}
                                            <div className="font-semibold text-gray-800 whitespace-normal line-clamp-2 max-w-[200px]">
                                                {part.name}
                                            </div>
                                        </div>
                                    </td>
                                    <td className="px-6 py-4">
                                        <span className="inline-flex items-center px-3 py-1 rounded-full text-sm font-semibold bg-green-50 text-green-700 border border-green-100">
                                            {part.price.toLocaleString('vi-VN', { maximumFractionDigits: 0 })} VNĐ
                                        </span>
                                    </td>
                                    <td className="px-6 py-4">
                                        <div className="text-sm text-gray-600 whitespace-normal line-clamp-2 max-w-xs" title={part.description}>
                                            {part.description || <span className="text-gray-400 italic">No description</span>}
                                        </div>
                                    </td>
                                    <td className="px-6 py-4">
                                        <span className="inline-flex items-center px-3 py-1 rounded-full text-xs font-medium bg-purple-50 text-purple-700 border border-purple-100">
                                            {part.categoryName || 'Uncategorized'}
                                        </span>
                                    </td>
                                    <td className="px-6 py-4">
                                        <div className="flex justify-center gap-2 opacity-0 group-hover:opacity-100 transition-opacity">
                                            <button
                                                onClick={() => handleOpenModal(part)}
                                                className="p-2 text-blue-600 hover:bg-blue-100 rounded-lg transition-colors"
                                                title="Edit"
                                            >
                                                <Edit size={18} />
                                            </button>
                                            <button
                                                onClick={() => handleDelete(part.id)}
                                                className="p-2 text-red-500 hover:bg-red-50 rounded-lg transition-colors"
                                                title="Delete"
                                            >
                                                <Trash2 size={18} />
                                            </button>
                                        </div>
                                    </td>
                                </tr>
                            ))}
                            {filteredParts.length === 0 && (
                                <tr>
                                    <td colSpan={6} className="px-6 py-12 text-center">
                                        <div className="flex flex-col items-center justify-center text-gray-400">
                                            <Package size={48} className="mb-4 text-gray-300" />
                                            <p className="text-lg font-medium text-gray-600">No spare parts found</p>
                                            <p className="text-sm mt-1">Try changing your search terms or add a new part.</p>
                                        </div>
                                    </td>
                                </tr>
                            )}
                        </tbody>
                    </table>
                </div>
            </div>

            <SparePartModal
                isOpen={isModalOpen}
                onClose={handleCloseModal}
                part={selectedPart}
                onSuccess={fetchSpareParts}
            />
        </div>
    );
};

export default SparePartManagement;