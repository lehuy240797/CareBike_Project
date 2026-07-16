import React, { useState, useEffect, useCallback } from 'react';
import { useWebSocketEvent } from '../context/WebSocketContext';
import { Plus, Trash2, Package, Search, LayoutGrid, List, Wrench, ChevronLeft, ChevronRight } from 'lucide-react';
import toast from 'react-hot-toast';
import SparePartModal from '../components/modals/SparePartModal';
import apiClient from '../services/apiClient';
import {
  badgeNeutral,
  badgeSuccess,
  btnPrimary,
  dashTitle,
  eyebrow,
  iconBtnDelete,
  iconBtnEdit,
  pageSubtitle,
  tableCard,
  tableEmpty,
  dataTable,
  tableScroll,
  tableSpinner,
  thCell,
  tdCell,
  tableRow,
} from '../ui/styles';

export interface SparePart {
  id: number;
  name: string;
  price: number;
  description: string;
  imageUrl: string | null;
  categoryId?: number;
  categoryName?: string;
}

// Reuse similar pill and viewBtn as CustomerManagement
const searchInputStyle =
  'w-full rounded-2xl border border-edge bg-primary-light/40 py-2.5 pl-10 pr-4 text-sm outline-none transition-all focus:border-primary focus:ring-2 focus:ring-primary/20';
const viewBtn = (active: boolean) =>
  `flex items-center gap-1.5 rounded-xl px-3 py-1.5 text-xs font-semibold transition-all ${
    active ? 'bg-primary text-white shadow' : 'text-primary-deep hover:bg-primary-muted'
  }`;

const SparePartManagement: React.FC = () => {
  const [spareParts, setSpareParts] = useState<SparePart[]>([]);
  const [searchTerm, setSearchTerm] = useState('');
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [selectedPart, setSelectedPart] = useState<SparePart | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [view, setView] = useState<'grid' | 'table'>('table');
  const [currentPage, setCurrentPage] = useState(1);
  const itemsPerPage = 10;

  const fetchSpareParts = useCallback(async (background = false) => {
    try {
      if (!background) setIsLoading(true);
      const response = await apiClient.get('/spare-parts');
      if (response.status === 200) {
        setSpareParts(response.data);
      } else {
        toast.error('Error loading spare parts data!');
      }
    } catch (error) {
      console.error('Connection error:', error);
      toast.error('Unable to connect to server!');
    } finally {
      setIsLoading(false);
    }
  }, []);

  useWebSocketEvent('SPARE_PART_UPDATED', () => { void fetchSpareParts(true); });

  useEffect(() => {
    void Promise.resolve().then(() => fetchSpareParts());
  }, [fetchSpareParts]);

  const handleOpenModal = (part?: SparePart) => {
    setSelectedPart(part || null);
    setIsModalOpen(true);
  };

  const handleCloseModal = () => {
    setIsModalOpen(false);
    setSelectedPart(null);
  };

  const handleDelete = async (id: number) => {
    if (window.confirm('Are you sure you want to delete this spare part?')) {
      try {
        const response = await apiClient.delete(`/spare-parts/${id}`);
        if (response.status === 204 || response.status === 200) {
          toast.success('Spare part deleted successfully!');
          fetchSpareParts();
        } else {
          toast.error('Error deleting from server!');
        }
      } catch (error) {
        toast.error('Error connecting to server!');
      }
    }
  };

  const filteredParts = spareParts.filter(
    (part) =>
      part.name.toLowerCase().includes(searchTerm.toLowerCase()) ||
      (part.description && part.description.toLowerCase().includes(searchTerm.toLowerCase()))
  );

  const totalPages = Math.ceil(filteredParts.length / itemsPerPage);
  const startIndex = (currentPage - 1) * itemsPerPage;
  const paginatedParts = filteredParts.slice(startIndex, startIndex + itemsPerPage);

  useEffect(() => {
    setCurrentPage(1);
  }, [searchTerm, view]);

  return (
    <div className="mx-auto max-w-[80rem]">
      {/* Header */}
      <div className="mb-8 flex flex-col items-start justify-between gap-4 animate-fade-up sm:flex-row sm:items-center">
        <div>
          <p className={eyebrow}>Inventory</p>
          <h1 className={`${dashTitle} mt-1`}>Spare Parts</h1>
          <p className={pageSubtitle}>Manage inventory, pricing, and spare part details</p>
        </div>
        <button type="button" onClick={() => handleOpenModal()} className={btnPrimary}>
          <Plus size={18} /> Add Spare Part
        </button>
      </div>

      {/* Filter bar */}
      <div className="mb-6 flex flex-wrap items-center gap-4 rounded-3xl border border-edge bg-white p-4 shadow-sm animate-fade-up" style={{ animationDelay: '0.1s' }}>
        <div className="relative min-w-48 flex-1">
          <Search size={16} className="absolute left-3.5 top-1/2 -translate-y-1/2 text-ink-muted" aria-hidden="true" />
          <input
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
            placeholder="Search parts by name or description..."
            className={searchInputStyle}
          />
        </div>
        <div className="flex items-center gap-1 rounded-2xl border border-edge bg-primary-light/50 p-1">
          <button type="button" onClick={() => setView('grid')} className={viewBtn(view === 'grid')}>
            <LayoutGrid size={14} /> Grid
          </button>
          <button type="button" onClick={() => setView('table')} className={viewBtn(view === 'table')}>
            <List size={14} /> Table
          </button>
        </div>
      </div>

      {/* Content */}
      {isLoading ? (
        <div className={`${tableCard} animate-fade-up`} style={{ animationDelay: '0.2s' }}>
          <div className={tableEmpty}>
            <div className={tableSpinner} aria-label="Loading..." />
            <p className="m-0">Loading spare parts...</p>
          </div>
        </div>
      ) : filteredParts.length === 0 ? (
        <div className="rounded-3xl border-2 border-dashed border-edge bg-white py-20 text-center animate-fade-up" style={{ animationDelay: '0.2s' }}>
          <Package size={40} className="mx-auto mb-3 text-primary opacity-40" aria-hidden="true" />
          <h3 className="m-0 font-display text-xl font-black text-ink">No spare parts found</h3>
          <p className="mt-1 text-sm text-ink-muted">Try changing your search terms or add a new part.</p>
        </div>
      ) : view === 'table' ? (
        /* TABLE VIEW */
        <div className={`${tableCard} animate-fade-up`} style={{ animationDelay: '0.2s' }}>
          <div className={tableScroll}>
            <table className={dataTable}>
              <thead>
                <tr>
                  <th className={thCell}>ID</th>
                  <th className={thCell}>Product</th>
                  <th className={thCell}>Category</th>
                  <th className={thCell}>Price</th>
                  <th className={`${thCell} text-right`}>Actions</th>
                </tr>
              </thead>
              <tbody className="[&>tr:last-child>td]:border-b-0">
                {paginatedParts.map((part) => (
                  <tr key={part.id} className={tableRow}>
                    <td className={`${tdCell} text-sm text-ink-muted`}>#{part.id}</td>
                    <td className={tdCell}>
                      <div className="flex items-center gap-3">
                        {part.imageUrl ? (
                          <div className="h-12 w-12 shrink-0 overflow-hidden rounded-xl border border-edge bg-white">
                            <img src={part.imageUrl} alt={part.name} className="h-full w-full object-cover" />
                          </div>
                        ) : (
                          <div className="flex h-12 w-12 shrink-0 items-center justify-center rounded-xl border border-edge bg-primary-light/30">
                            <Package size={20} className="text-primary/50" />
                          </div>
                        )}
                        <div>
                          <div className="font-semibold">{part.name}</div>
                          <div className="mt-0.5 max-w-[250px] truncate text-[0.8125rem] text-ink-muted" title={part.description || ''}>
                            {part.description || 'No description'}
                          </div>
                        </div>
                      </div>
                    </td>
                    <td className={tdCell}>
                      <span className={badgeNeutral}>
                        {part.categoryName || 'Uncategorized'}
                      </span>
                    </td>
                    <td className={tdCell}>
                      <span className={badgeSuccess}>
                        {part.price.toLocaleString('vi-VN')} VNĐ
                      </span>
                    </td>
                    <td className={tdCell}>
                      <div className="flex items-center justify-end gap-1.5 opacity-60 transition-opacity hover:opacity-100">
                        <button
                          type="button"
                          className={iconBtnEdit}
                          onClick={() => handleOpenModal(part)}
                          title="Edit"
                        >
                          <Wrench size={15} />
                        </button>
                        <button
                          type="button"
                          className={iconBtnDelete}
                          onClick={() => handleDelete(part.id)}
                          title="Delete"
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
        </div>
      ) : (
        /* GRID VIEW */
        <div className="grid grid-cols-1 gap-5 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 animate-fade-up" style={{ animationDelay: '0.2s' }}>
          {paginatedParts.map((part) => (
            <div
              key={part.id}
              className="group flex flex-col overflow-hidden rounded-3xl border border-edge bg-white transition-all duration-300 hover:-translate-y-1 hover:border-primary hover:shadow-[0_10px_35px_rgba(249,115,22,0.12)]"
            >
              {/* Image Header */}
              <div className="relative h-48 w-full border-b border-edge bg-primary-light/20">
                {part.imageUrl ? (
                  <img src={part.imageUrl} alt={part.name} className="h-full w-full object-cover" />
                ) : (
                  <div className="flex h-full w-full items-center justify-center">
                    <Package size={48} className="text-primary/30" />
                  </div>
                )}
                <div className="absolute right-3 top-3">
                  <span className={`${badgeSuccess} shadow-md`}>
                    {part.price.toLocaleString('vi-VN')} VNĐ
                  </span>
                </div>
              </div>
              
              {/* Content */}
              <div className="flex flex-1 flex-col p-5">
                <div className="mb-2">
                  <span className={badgeNeutral}>
                    {part.categoryName || 'Uncategorized'}
                  </span>
                </div>
                <h3 className="m-0 mb-1.5 font-display text-lg font-black leading-tight text-ink">
                  {part.name}
                </h3>
                <p className="m-0 mb-4 line-clamp-2 text-sm text-ink-muted">
                  {part.description || 'No description available.'}
                </p>
                
                {/* Spacer to push actions to bottom */}
                <div className="mt-auto flex items-center justify-between border-t border-edge pt-4">
                  <span className="text-xs text-ink-muted/70">ID: #{part.id}</span>
                  <div className="flex gap-1.5">
                    <button
                      type="button"
                      className={iconBtnEdit}
                      onClick={() => handleOpenModal(part)}
                      title="Edit"
                    >
                      <Wrench size={15} />
                    </button>
                    <button
                      type="button"
                      className={iconBtnDelete}
                      onClick={() => handleDelete(part.id)}
                      title="Delete"
                    >
                      <Trash2 size={15} />
                    </button>
                  </div>
                </div>
              </div>
            </div>
          ))}
        </div>
      )}

      {totalPages > 1 && !isLoading && (
        <div className="mt-8 flex items-center justify-center gap-3 animate-fade-up" style={{ animationDelay: '0.3s' }}>
          <button
            onClick={() => setCurrentPage(p => Math.max(1, p - 1))}
            disabled={currentPage === 1}
            className="flex items-center justify-center h-9 w-9 rounded-xl border border-edge bg-white transition hover:bg-primary-light hover:text-primary disabled:opacity-40 disabled:hover:bg-white disabled:hover:text-ink"
          >
            <ChevronLeft size={18} />
          </button>
          <span className="text-sm font-semibold text-ink-muted">
            Page <span className="text-ink">{currentPage}</span> of <span className="text-ink">{totalPages}</span>
          </span>
          <button
            onClick={() => setCurrentPage(p => Math.min(totalPages, p + 1))}
            disabled={currentPage === totalPages}
            className="flex items-center justify-center h-9 w-9 rounded-xl border border-edge bg-white transition hover:bg-primary-light hover:text-primary disabled:opacity-40 disabled:hover:bg-white disabled:hover:text-ink"
          >
            <ChevronRight size={18} />
          </button>
        </div>
      )}

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

