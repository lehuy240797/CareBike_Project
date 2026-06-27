import React, { useState, useEffect, type FormEvent } from 'react';
import toast from 'react-hot-toast';
import type { SparePart } from '../../pages/SparePartManagement';
import { X, UploadCloud, Package, DollarSign, FileText, Layers } from 'lucide-react';
import apiClient from '../../services/apiClient';
import { getCategories, type CategoryRecord } from '../../services/categoryService';

interface Props {
    isOpen: boolean;
    onClose: () => void;
    part: SparePart | null;
    onSuccess: () => void;
}

const SparePartModal: React.FC<Props> = ({ isOpen, onClose, part, onSuccess }) => {
    const [name, setName] = useState('');
    const [price, setPrice] = useState<number | ''>('');
    const [description, setDescription] = useState('');
    const [imageFile, setImageFile] = useState<File | null>(null);
    const [previewUrl, setPreviewUrl] = useState<string | null>(null);
    const [categoryId, setCategoryId] = useState<number | ''>('');
    const [categories, setCategories] = useState<CategoryRecord[]>([]);

    useEffect(() => {
        getCategories().then(setCategories).catch(() => {});
    }, []);

    useEffect(() => {
        if (part) {
            setName(part.name);
            setPrice(part.price);
            setDescription(part.description || '');
            setPreviewUrl(part.imageUrl);
            setImageFile(null);
            setCategoryId(part.categoryId || '');
        } else {
            setName('');
            setPrice('');
            setDescription('');
            setImageFile(null);
            setPreviewUrl(null);
            setCategoryId('');
        }
    }, [part, isOpen]);

    if (!isOpen) return null;

    const handleImageChange = (e: React.ChangeEvent<HTMLInputElement>) => {
        if (e.target.files && e.target.files[0]) {
            const file = e.target.files[0];
            setImageFile(file);
            setPreviewUrl(URL.createObjectURL(file));
        }
    };

    const handleSubmit = async (e: FormEvent) => {
        e.preventDefault();

        const formData = new FormData();
        formData.append('name', name);
        formData.append('price', price.toString());
        formData.append('description', description);
        if (imageFile) {
            formData.append('image', imageFile);
        }
        if (categoryId) {
            formData.append('categoryId', categoryId.toString());
        }

        try {
            if (part) {
                const response = await apiClient.put(`/spare-parts/${part.id}`, formData, {
                    headers: {
                        'Content-Type': 'multipart/form-data'
                    }
                });

                if (response.status === 200) {
                    toast.success('Cập nhật phụ tùng thành công!');
                    onSuccess();
                    onClose();
                } else {
                    toast.error('Có lỗi từ máy chủ khi cập nhật!');
                }
            } else {
                const response = await apiClient.post('/spare-parts', formData, {
                    headers: {
                        'Content-Type': 'multipart/form-data'
                    }
                });

                if (response.status === 201 || response.status === 200) {
                    toast.success('Thêm mới phụ tùng thành công!');
                    onSuccess();
                    onClose();
                } else {
                    toast.error('Có lỗi từ máy chủ khi thêm mới!');
                }
            }
        } catch (error) {
            toast.error('Lỗi kết nối đến máy chủ.');
            console.error(error);
        }
    };

    return (
        <div className="fixed inset-0 bg-gray-900/40 backdrop-blur-sm flex items-center justify-center z-50 p-4 transition-opacity duration-300">
            <div className="bg-white rounded-3xl shadow-2xl w-full max-w-xl overflow-hidden transform transition-all duration-300 scale-100 opacity-100 flex flex-col max-h-[90vh]">
                
                {/* Header */}
                <div className="px-8 py-5 border-b border-gray-100 flex justify-between items-center bg-white sticky top-0 z-10">
                    <div className="flex items-center gap-3">
                        <div className="p-2 bg-blue-50 rounded-xl text-blue-600">
                            <Package size={22} />
                        </div>
                        <div>
                            <h2 className="text-xl font-bold text-gray-800 tracking-tight">
                                {part ? 'Cập nhật Phụ tùng' : 'Thêm Phụ tùng mới'}
                            </h2>
                            <p className="text-xs text-gray-500 font-medium mt-0.5">
                                Điền các thông tin cơ bản cho sản phẩm
                            </p>
                        </div>
                    </div>
                    <button 
                        onClick={onClose} 
                        className="p-2 text-gray-400 hover:text-red-500 hover:bg-red-50 rounded-full transition-colors"
                        aria-label="Đóng"
                    >
                        <X size={22} />
                    </button>
                </div>

                {/* Body / Form */}
                <form onSubmit={handleSubmit} className="flex-1 overflow-y-auto px-8 py-6 space-y-6 custom-scrollbar">
                    
                    {/* Tên Phụ Tùng */}
                    <div className="space-y-2">
                        <label className="block text-sm font-semibold text-gray-700">Tên phụ tùng <span className="text-red-500">*</span></label>
                        <div className="relative">
                            <div className="absolute inset-y-0 left-0 pl-3.5 flex items-center pointer-events-none">
                                <Package size={18} className="text-gray-400" />
                            </div>
                            <input
                                type="text" 
                                required 
                                value={name} 
                                onChange={(e) => setName(e.target.value)}
                                className="w-full pl-10 pr-4 py-2.5 border border-gray-200 rounded-xl focus:outline-none focus:border-blue-500 focus:ring-2 focus:ring-blue-100 transition-all text-gray-800 font-medium placeholder-gray-400"
                                placeholder="VD: Nhớt Motul 5w40, Má phanh đĩa..."
                            />
                        </div>
                    </div>

                    {/* Giá bán */}
                    <div className="space-y-2">
                        <label className="block text-sm font-semibold text-gray-700">Giá bán (VNĐ) <span className="text-red-500">*</span></label>
                        <div className="relative">
                            <div className="absolute inset-y-0 left-0 pl-3.5 flex items-center pointer-events-none">
                                <DollarSign size={18} className="text-gray-400" />
                            </div>
                            <input
                                type="number" 
                                required 
                                min="0" 
                                value={price} 
                                onChange={(e) => setPrice(Number(e.target.value))}
                                className="w-full pl-10 pr-4 py-2.5 border border-gray-200 rounded-xl focus:outline-none focus:border-blue-500 focus:ring-2 focus:ring-blue-100 transition-all text-gray-800 font-bold placeholder-gray-400 tracking-wide"
                                placeholder="VD: 150000"
                            />
                            <div className="absolute inset-y-0 right-0 pr-4 flex items-center pointer-events-none">
                                <span className="text-gray-400 font-medium text-sm">VNĐ</span>
                            </div>
                        </div>
                    </div>

                    {/* Chọn danh mục */}
                    <div className="space-y-2">
                        <label className="block text-sm font-semibold text-gray-700">Danh mục sản phẩm</label>
                        <div className="relative">
                            <div className="absolute inset-y-0 left-0 pl-3.5 flex items-center pointer-events-none">
                                <Layers size={18} className="text-gray-400" />
                            </div>
                            <select
                                value={categoryId}
                                onChange={(e) => setCategoryId(e.target.value ? Number(e.target.value) : '')}
                                className="w-full pl-10 pr-4 py-2.5 border border-gray-200 rounded-xl focus:outline-none focus:border-blue-500 focus:ring-2 focus:ring-blue-100 transition-all text-gray-800 font-medium bg-white"
                            >
                                <option value="">-- Chưa phân loại --</option>
                                {categories.map(c => (
                                    <option key={c.id} value={c.id}>{c.name}</option>
                                ))}
                            </select>
                        </div>
                    </div>

                    {/* Mô tả */}
                    <div className="space-y-2">
                        <label className="block text-sm font-semibold text-gray-700">Mô tả chi tiết</label>
                        <div className="relative">
                            <div className="absolute top-3 left-3.5 pointer-events-none">
                                <FileText size={18} className="text-gray-400" />
                            </div>
                            <textarea
                                rows={4} 
                                value={description} 
                                onChange={(e) => setDescription(e.target.value)}
                                className="w-full pl-10 pr-4 py-3 border border-gray-200 rounded-xl focus:outline-none focus:border-blue-500 focus:ring-2 focus:ring-blue-100 transition-all text-gray-700 resize-y"
                                placeholder="Viết mô tả ngắn gọn về sản phẩm, công dụng, dòng xe tương thích..."
                            />
                        </div>
                    </div>

                    {/* Vùng chọn ảnh */}
                    <div className="space-y-2">
                        <label className="block text-sm font-semibold text-gray-700">Hình ảnh sản phẩm</label>
                        <div className="mt-2 flex justify-center rounded-2xl border-2 border-dashed border-gray-300 px-6 py-8 hover:bg-gray-50 hover:border-blue-400 transition-colors group relative cursor-pointer overflow-hidden">
                            
                            {/* Input ẩn toàn màn hình vùng chọn */}
                            <input
                                type="file" 
                                accept="image/*" 
                                onChange={handleImageChange}
                                className="absolute inset-0 w-full h-full opacity-0 cursor-pointer z-20"
                            />

                            {previewUrl ? (
                                <div className="text-center z-10 relative flex flex-col items-center">
                                    <div className="relative group/img rounded-xl overflow-hidden shadow-sm border border-gray-200">
                                        <img src={previewUrl} alt="Preview" className="w-32 h-32 object-cover" />
                                        <div className="absolute inset-0 bg-black/40 opacity-0 group-hover/img:opacity-100 transition-opacity flex items-center justify-center">
                                            <span className="text-white text-xs font-medium bg-black/60 px-2 py-1 rounded-md">Thay đổi</span>
                                        </div>
                                    </div>
                                    <p className="mt-3 text-sm font-medium text-blue-600 group-hover:underline cursor-pointer relative z-10">
                                        Chọn ảnh khác
                                    </p>
                                </div>
                            ) : (
                                <div className="text-center z-10 relative">
                                    <div className="mx-auto flex h-14 w-14 items-center justify-center rounded-full bg-blue-50 text-blue-600 mb-3 group-hover:scale-110 transition-transform">
                                        <UploadCloud size={28} />
                                    </div>
                                    <div className="flex text-sm text-gray-600 justify-center">
                                        <span className="relative font-semibold text-blue-600 group-hover:text-blue-500 rounded-md">
                                            Nhấn vào đây để tải ảnh lên
                                        </span>
                                    </div>
                                    <p className="text-xs text-gray-500 mt-2">PNG, JPG, WEBP, GIF tối đa 5MB</p>
                                </div>
                            )}
                        </div>
                    </div>
                </form>

                {/* Footer Buttons */}
                <div className="px-8 py-5 bg-gray-50 border-t border-gray-100 flex justify-end gap-3 sticky bottom-0 z-10 rounded-b-3xl">
                    <button 
                        type="button" 
                        onClick={onClose} 
                        className="px-6 py-2.5 rounded-xl text-gray-600 font-medium hover:bg-gray-200/50 hover:text-gray-900 transition-colors focus:ring-2 focus:ring-gray-200 focus:outline-none"
                    >
                        Hủy bỏ
                    </button>
                    <button 
                        type="submit" 
                        onClick={handleSubmit}
                        className="px-6 py-2.5 bg-blue-600 text-white font-semibold rounded-xl shadow-sm hover:shadow-md hover:bg-blue-700 hover:-translate-y-0.5 active:translate-y-0 transition-all focus:ring-2 focus:ring-blue-400 focus:ring-offset-2 focus:outline-none"
                    >
                        {part ? 'Lưu thay đổi' : 'Xác nhận Thêm mới'}
                    </button>
                </div>

            </div>
        </div>
    );
};

export default SparePartModal;