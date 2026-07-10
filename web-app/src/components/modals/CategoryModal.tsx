import React, { useState } from 'react';
import toast from 'react-hot-toast';
import { Layers } from 'lucide-react';
import ModalOverlay from './ModalOverlay';
import { btnOutline, btnPrimary, formGroup, inputBase, label, modalFooter, modalForm } from '../../ui/styles';
import { createCategory } from '../../services/categoryService';

interface Props {
  isOpen: boolean;
  onClose: () => void;
  onSuccess: () => void;
}

const CategoryModal: React.FC<Props> = ({ isOpen, onClose, onSuccess }) => {
  const [name, setName] = useState('');
  const [description, setDescription] = useState('');
  const [isSaving, setIsSaving] = useState(false);

  if (!isOpen) return null;

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!name.trim()) return toast.error('Please enter a category name');
    
    setIsSaving(true);
    try {
      await createCategory({ name, description });
      toast.success('Category added successfully');
      onSuccess();
      onClose();
      // Reset form
      setName('');
      setDescription('');
    } catch {
      toast.error('Error adding category');
    } finally {
      setIsSaving(false);
    }
  };

  return (
    <ModalOverlay isOpen={isOpen} onClose={onClose} title="Add New Category" icon={<Layers />}>
      <form onSubmit={handleSubmit} className={modalForm}>
        <div className={formGroup}>
          <label className={label}>
            Category Name <span className="text-red-500">*</span>
          </label>
          <input
            type="text"
            className={inputBase}
            value={name}
            onChange={(e) => setName(e.target.value)}
            placeholder="e.g.: Motor Oil"
            required
            autoFocus
          />
        </div>

        <div className={formGroup}>
          <label className={label}>Description (Optional)</label>
          <textarea
            className={inputBase}
            rows={3}
            value={description}
            onChange={(e) => setDescription(e.target.value)}
            placeholder="Enter category description..."
          />
        </div>

        <div className={modalFooter}>
          <button type="button" className={btnOutline} onClick={onClose} disabled={isSaving}>
            Cancel
          </button>
          <button type="submit" className={btnPrimary} disabled={isSaving}>
            {isSaving ? 'Saving...' : 'Add Category'}
          </button>
        </div>
      </form>
    </ModalOverlay>
  );
};

export default CategoryModal;
