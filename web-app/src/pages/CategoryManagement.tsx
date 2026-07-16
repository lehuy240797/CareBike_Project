import { useState, useEffect, useCallback } from 'react';
import { useWebSocketEvent } from '../context/WebSocketContext';
import { Layers, Plus, Trash2 } from 'lucide-react';
import { getCategories, deleteCategory } from '../services/categoryService';
import type { CategoryRecord } from '../services/categoryService';
import toast from 'react-hot-toast';
import CategoryModal from '../components/modals/CategoryModal';
import {
  btnPrimary,
  dashTitle,
  eyebrow,
  pageSubtitle,
  tableCard,
  dataTable,
  thCell,
  tdCell,
  tableRow,
  iconBtnDelete,
  tableScroll,
  tableEmpty,
  tableSpinner,
} from '../ui/styles';

const CategoryManagement = () => {
  const [categories, setCategories] = useState<CategoryRecord[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [isModalOpen, setIsModalOpen] = useState(false);

  const fetchCategories = useCallback(async (background = false) => {
    try {
      if (!background) setIsLoading(true);
      const data = await getCategories();
      setCategories(data);
    } catch {
      toast.error('Error loading categories');
    } finally {
      setIsLoading(false);
    }
  }, []);

  useWebSocketEvent('SPARE_PART_UPDATED', () => fetchCategories(true));

  useEffect(() => {
    fetchCategories();
  }, [fetchCategories]);

  const handleDelete = async (id: number) => {
    if (!window.confirm('Are you sure you want to delete this category?')) return;
    try {
      await deleteCategory(id);
      setCategories(categories.filter((c) => c.id !== id));
      toast.success('Category deleted');
    } catch {
      toast.error('Cannot delete this category (might contain spare parts)');
    }
  };

  return (
    <div className="mx-auto max-w-[80rem]">
      {/* Header */}
      <div className="mb-8 flex flex-col items-start justify-between gap-4 animate-fade-up sm:flex-row sm:items-center">
        <div>
          <p className={eyebrow}>Category Management</p>
          <h1 className={`${dashTitle} mt-1`}>Categories</h1>
          <p className={pageSubtitle}>
            Create categories to classify spare parts (e.g., Oil, Tires...)
          </p>
        </div>
        <button type="button" className={btnPrimary} onClick={() => setIsModalOpen(true)}>
          <Plus size={18} /> Add Category
        </button>
      </div>

      {/* Main Table */}
      <div className={`${tableCard} animate-fade-up`} style={{ animationDelay: '0.1s' }}>
        {isLoading ? (
          <div className={tableEmpty}>
            <div className={tableSpinner} aria-label="Loading..." />
            <p className="m-0">Loading categories...</p>
          </div>
        ) : categories.length === 0 ? (
          <div className="rounded-3xl border-2 border-dashed border-edge bg-white py-20 text-center">
            <Layers size={40} className="mx-auto mb-3 text-primary opacity-40" aria-hidden="true" />
            <h3 className="m-0 font-display text-xl font-black text-ink">No categories found</h3>
            <p className="mt-1 text-sm text-ink-muted">Start by adding a new category.</p>
          </div>
        ) : (
          <div className={tableScroll}>
            <table className={dataTable}>
              <thead>
                <tr>
                  <th className={thCell}>ID</th>
                  <th className={thCell}>Category Name</th>
                  <th className={thCell}>Description</th>
                  <th className={`${thCell} text-right`}>Actions</th>
                </tr>
              </thead>
              <tbody className="[&>tr:last-child>td]:border-b-0">
                {categories.map((c) => (
                  <tr key={c.id} className={tableRow}>
                    <td className={`${tdCell} text-sm text-ink-muted`}>#{c.id}</td>
                    <td className={`${tdCell} font-semibold`}>{c.name}</td>
                    <td className={`${tdCell} text-ink-muted`}>{c.description || '—'}</td>
                    <td className={tdCell}>
                      <div className="flex items-center justify-end gap-1.5">
                        <button
                          type="button"
                          className={iconBtnDelete}
                          onClick={() => handleDelete(c.id)}
                          title="Delete Category"
                        >
                          <Trash2 size={15} />
                        </button>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>

      <CategoryModal
        isOpen={isModalOpen}
        onClose={() => setIsModalOpen(false)}
        onSuccess={fetchCategories}
      />
    </div>
  );
};

export default CategoryManagement;

