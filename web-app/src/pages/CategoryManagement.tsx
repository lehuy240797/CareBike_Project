import React, { useState, useEffect, useCallback } from 'react';
import { Layers, Plus, Trash2 } from 'lucide-react';
import { getCategories, createCategory, deleteCategory } from '../services/categoryService';
import type { CategoryRecord } from '../services/categoryService';
import toast from 'react-hot-toast';

const CategoryManagement = () => {
  const [categories, setCategories] = useState<CategoryRecord[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [isSaving, setIsSaving] = useState(false);

  const [name, setName] = useState('');
  const [description, setDescription] = useState('');

  const fetchCategories = useCallback(async () => {
    try {
      setIsLoading(true);
      const data = await getCategories();
      setCategories(data);
    } catch {
      toast.error('Error loading categories');
    } finally {
      setIsLoading(false);
    }
  }, []);

  useEffect(() => { fetchCategories(); }, [fetchCategories]);

  const handleCreate = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!name.trim()) return toast.error('Please enter a category name');
    setIsSaving(true);
    try {
      const saved = await createCategory({ name, description });
      setCategories([...categories, saved]);
      setName('');
      setDescription('');
      toast.success('Category added successfully');
    } catch {
      toast.error('Error adding category');
    } finally {
      setIsSaving(false);
    }
  };

  const handleDelete = async (id: number) => {
    if (!window.confirm('Are you sure you want to delete this category?')) return;
    try {
      await deleteCategory(id);
      setCategories(categories.filter(c => c.id !== id));
      toast.success('Category deleted');
    } catch {
      toast.error('Cannot delete this category (might contain spare parts)');
    }
  };

  return (
    <div className="dashboard-inner">
      <div className="page-header" style={{ marginBottom: '1.75rem' }}>
        <Layers size={28} className="page-header-icon" />
        <div style={{ flex: 1 }}>
          <h1 className="dashboard-title" style={{ margin: 0 }}>Category Management</h1>
          <p className="page-subtitle">Create categories to classify spare parts (e.g., Oil, Tires...)</p>
        </div>
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: '300px 1fr', gap: '24px' }}>
        <div className="table-card" style={{ padding: '20px', height: 'fit-content' }}>
          <h3 style={{ marginBottom: '16px' }}>Add New Category</h3>
          <form onSubmit={handleCreate}>
            <div className="form-group">
              <label>Category Name <span className="text-red-500">*</span></label>
              <input type="text" className="form-input" value={name} onChange={e => setName(e.target.value)} placeholder="e.g.: Motor Oil" required />
            </div>
            <div className="form-group" style={{ marginTop: '16px' }}>
              <label>Description (Optional)</label>
              <textarea className="form-input" rows={3} value={description} onChange={e => setDescription(e.target.value)} />
            </div>
            <button type="submit" className="app-btn" style={{ width: '100%', marginTop: '20px' }} disabled={isSaving}>
              {isSaving ? 'Saving...' : 'Add Category'}
            </button>
          </form>
        </div>

        <div className="table-card">
          {isLoading ? (
            <div className="table-empty"><p>Loading data...</p></div>
          ) : categories.length === 0 ? (
            <div className="table-empty"><p>No categories found.</p></div>
          ) : (
            <div className="table-scroll">
              <table className="data-table">
                <thead>
                  <tr>
                    <th>ID</th>
                    <th>Category Name</th>
                    <th>Description</th>
                    <th style={{ textAlign: 'right' }}>Actions</th>
                  </tr>
                </thead>
                <tbody>
                  {categories.map((c) => (
                    <tr key={c.id}>
                      <td className="td-muted">{c.id}</td>
                      <td className="font-medium">{c.name}</td>
                      <td>{c.description || '—'}</td>
                      <td>
                        <div className="table-actions">
                          <button type="button" className="icon-btn icon-btn--delete" onClick={() => handleDelete(c.id)}>
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
      </div>
    </div>
  );
};

export default CategoryManagement;
