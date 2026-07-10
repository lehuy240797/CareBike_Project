import React, { useState, useEffect, type FormEvent } from 'react';
import toast from 'react-hot-toast';
import type { SparePart } from '../../pages/SparePartManagement';
import { Package, UploadCloud } from 'lucide-react';
import apiClient from '../../services/apiClient';
import { getCategories, type CategoryRecord } from '../../services/categoryService';
import ModalOverlay from './ModalOverlay';
import {
  btnOutline,
  btnPrimary,
  formGroup,
  formHint,
  inputBase,
  label,
  modalFooter,
  modalForm,
  selectBase
} from '../../ui/styles';

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
  const [isSaving, setIsSaving] = useState(false);

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
    setIsSaving(true);

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
          headers: { 'Content-Type': 'multipart/form-data' },
        });

        if (response.status === 200) {
          toast.success('Spare part updated successfully!');
          onSuccess();
          onClose();
        } else {
          toast.error('Server error during update!');
        }
      } else {
        const response = await apiClient.post('/spare-parts', formData, {
          headers: { 'Content-Type': 'multipart/form-data' },
        });

        if (response.status === 201 || response.status === 200) {
          toast.success('Spare part created successfully!');
          onSuccess();
          onClose();
        } else {
          toast.error('Server error during creation!');
        }
      }
    } catch (error) {
      toast.error('Connection error.');
      console.error(error);
    } finally {
      setIsSaving(false);
    }
  };

  return (
    <ModalOverlay 
      isOpen={isOpen} 
      onClose={onClose} 
      title={part ? 'Edit Spare Part' : 'Add New Spare Part'} 
      icon={<Package />}
    >
      <form onSubmit={handleSubmit} className={modalForm}>
        <div className={formGroup}>
          <label className={label}>
            Part Name <span className="text-red-500">*</span>
          </label>
          <input
            type="text"
            required
            value={name}
            onChange={(e) => setName(e.target.value)}
            className={inputBase}
            placeholder="e.g.: Brake Pads, Motor Oil"
          />
        </div>

        <div className={formGroup}>
          <label className={label}>
            Price (VNĐ) <span className="text-red-500">*</span>
          </label>
          <div className="relative">
            <input
              type="number"
              required
              min="0"
              value={price}
              onChange={(e) => setPrice(Number(e.target.value))}
              className={`${inputBase} pr-12`}
              placeholder="150000"
            />
            <div className="absolute inset-y-0 right-0 flex items-center pr-4 pointer-events-none">
              <span className="text-sm font-medium text-ink-muted">VNĐ</span>
            </div>
          </div>
        </div>

        <div className={formGroup}>
          <label className={label}>Category</label>
          <select
            value={categoryId}
            onChange={(e) => setCategoryId(e.target.value ? Number(e.target.value) : '')}
            className={selectBase}
          >
            <option value="">-- Uncategorized --</option>
            {categories.map((c) => (
              <option key={c.id} value={c.id}>{c.name}</option>
            ))}
          </select>
        </div>

        <div className={formGroup}>
          <label className={label}>Description (Optional)</label>
          <textarea
            rows={3}
            value={description}
            onChange={(e) => setDescription(e.target.value)}
            className={inputBase}
            placeholder="Details about compatibility or specifications..."
          />
        </div>

        <div className={formGroup}>
          <label className={label}>Product Image</label>
          <div className="relative group cursor-pointer overflow-hidden rounded-2xl border-2 border-dashed border-edge bg-primary-light/30 px-6 py-6 text-center transition-colors hover:border-primary hover:bg-primary-light">
            <input
              type="file"
              accept="image/*"
              onChange={handleImageChange}
              className="absolute inset-0 z-20 h-full w-full cursor-pointer opacity-0"
            />
            {previewUrl ? (
              <div className="relative z-10 mx-auto flex flex-col items-center">
                <div className="group/img relative overflow-hidden rounded-xl border border-edge shadow-sm">
                  <img src={previewUrl} alt="Preview" className="h-28 w-28 object-cover" />
                  <div className="absolute inset-0 flex items-center justify-center bg-black/40 text-xs font-medium text-white opacity-0 transition-opacity group-hover/img:opacity-100">
                    Change
                  </div>
                </div>
                <p className="mt-2 text-sm font-medium text-primary group-hover:underline">
                  Click to choose a different image
                </p>
              </div>
            ) : (
              <div className="relative z-10">
                <div className="mx-auto mb-2 flex h-12 w-12 items-center justify-center rounded-full bg-primary-light text-primary transition-transform group-hover:scale-110">
                  <UploadCloud size={24} />
                </div>
                <span className="text-sm font-semibold text-primary transition-colors group-hover:text-primary-hover">
                  Click to upload image
                </span>
                <p className={formHint}>PNG, JPG up to 5MB</p>
              </div>
            )}
          </div>
        </div>

        <div className={modalFooter}>
          <button type="button" onClick={onClose} className={btnOutline} disabled={isSaving}>
            Cancel
          </button>
          <button type="submit" className={btnPrimary} disabled={isSaving}>
            {isSaving ? 'Saving...' : part ? 'Save Changes' : 'Create Spare Part'}
          </button>
        </div>
      </form>
    </ModalOverlay>
  );
};

export default SparePartModal;