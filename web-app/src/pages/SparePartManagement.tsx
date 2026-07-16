import React, { useCallback, useEffect, useMemo, useState } from 'react';
import { ChevronLeft, ChevronRight, Eye, EyeOff, LayoutGrid, List, Package, Plus, Search, Wrench } from 'lucide-react';
import toast from 'react-hot-toast';
import SparePartModal from '../components/modals/SparePartModal';
import { useWebSocketEvent } from '../context/WebSocketContext';
import apiClient from '../services/apiClient';
import {
  badgeNeutral,
  badgeSuccess,
  btnPrimary,
  dashTitle,
  dataTable,
  eyebrow,
  iconBtnDelete,
  iconBtnEdit,
  iconBtnUnlock,
  pageSubtitle,
  tableCard,
  tableEmpty,
  tableRow,
  tableScroll,
  tableSpinner,
  tdCell,
  thCell,
} from '../ui/styles';

export interface SparePart {
  id: number;
  name: string;
  price: number;
  description: string;
  imageUrl: string | null;
  categoryId?: number;
  categoryName?: string;
  isActive: boolean;
}

type StatusFilter = 'all' | 'visible' | 'hidden';
type ViewMode = 'grid' | 'table';

const searchInputStyle =
  'w-full rounded-2xl border border-edge bg-primary-light/40 py-2.5 pl-10 pr-4 text-sm outline-none transition-all focus:border-primary focus:ring-2 focus:ring-primary/20';

const filterButton = (active: boolean) =>
  `flex items-center gap-1.5 rounded-xl px-3 py-1.5 text-xs font-semibold transition-all ${
    active ? 'bg-primary text-white shadow' : 'text-primary-deep hover:bg-primary-muted'
  }`;

const SparePartManagement: React.FC = () => {
  const [spareParts, setSpareParts] = useState<SparePart[]>([]);
  const [searchTerm, setSearchTerm] = useState('');
  const [statusFilter, setStatusFilter] = useState<StatusFilter>('all');
  const [view, setView] = useState<ViewMode>('table');
  const [currentPage, setCurrentPage] = useState(1);
  const [isLoading, setIsLoading] = useState(true);
  const [togglingPartId, setTogglingPartId] = useState<number | null>(null);
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [selectedPart, setSelectedPart] = useState<SparePart | null>(null);
  const itemsPerPage = 10;

  const fetchSpareParts = useCallback(async (background = false) => {
    try {
      if (!background) setIsLoading(true);
      const response = await apiClient.get<SparePart[]>('/spare-parts?activeOnly=false');
      setSpareParts(response.data);
    } catch (error) {
      console.error('Unable to load spare parts:', error);
      toast.error('Unable to load spare parts.');
    } finally {
      if (!background) setIsLoading(false);
    }
  }, []);

  useWebSocketEvent('SPARE_PART_UPDATED', () => {
    void fetchSpareParts(true);
  });

  useEffect(() => {
    void fetchSpareParts();
  }, [fetchSpareParts]);

  useEffect(() => {
    setCurrentPage(1);
  }, [searchTerm, statusFilter, view]);

  const handleOpenModal = (part?: SparePart) => {
    setSelectedPart(part ?? null);
    setIsModalOpen(true);
  };

  const handleCloseModal = () => {
    setIsModalOpen(false);
    setSelectedPart(null);
  };

  const handleToggleVisibility = async (part: SparePart) => {
    const nextVisible = !part.isActive;
    const action = nextVisible ? 'show' : 'hide';
    const confirmed = window.confirm(
      `${nextVisible ? 'Show' : 'Hide'} "${part.name}"? ${
        nextVisible
          ? 'It will be available to customers and branches again.'
          : 'It will no longer be available to customers and branches.'
      }`,
    );

    if (!confirmed) return;

    setTogglingPartId(part.id);
    try {
      await apiClient.put(`/spare-parts/${part.id}/toggle`);
      toast.success(`Spare part ${nextVisible ? 'shown' : 'hidden'} successfully!`);
      await fetchSpareParts(true);
    } catch (error) {
      console.error(`Unable to ${action} spare part:`, error);
      toast.error(`Unable to ${action} this spare part.`);
    } finally {
      setTogglingPartId(null);
    }
  };

  const filteredParts = useMemo(() => {
    const query = searchTerm.trim().toLowerCase();
    return spareParts.filter((part) => {
      const matchesStatus =
        statusFilter === 'all' ||
        (statusFilter === 'visible' ? part.isActive : !part.isActive);
      const matchesSearch =
        part.name.toLowerCase().includes(query) ||
        (part.description?.toLowerCase().includes(query) ?? false);
      return matchesStatus && matchesSearch;
    });
  }, [searchTerm, spareParts, statusFilter]);

  const totalPages = Math.max(1, Math.ceil(filteredParts.length / itemsPerPage));
  const page = Math.min(currentPage, totalPages);
  const startIndex = (page - 1) * itemsPerPage;
  const paginatedParts = filteredParts.slice(startIndex, startIndex + itemsPerPage);

  const visibilityButton = (part: SparePart) => (
    <button
      type="button"
      disabled={togglingPartId === part.id}
      className={part.isActive ? iconBtnDelete : iconBtnUnlock}
      onClick={() => handleToggleVisibility(part)}
      title={part.isActive ? 'Hide product' : 'Show product'}
      aria-label={part.isActive ? `Hide ${part.name}` : `Show ${part.name}`}
    >
      {part.isActive ? <EyeOff size={15} /> : <Eye size={15} />}
    </button>
  );

  return (
    <div className="mx-auto max-w-[80rem]">
      <div className="mb-8 flex flex-col items-start justify-between gap-4 animate-fade-up sm:flex-row sm:items-center">
        <div>
          <p className={eyebrow}>Inventory</p>
          <h1 className={`${dashTitle} mt-1`}>Spare Parts</h1>
          <p className={pageSubtitle}>Manage inventory, pricing, visibility, and spare part details</p>
        </div>
        <button type="button" onClick={() => handleOpenModal()} className={btnPrimary}>
          <Plus size={18} /> Add Spare Part
        </button>
      </div>

      <div className="mb-6 flex flex-wrap items-center gap-4 rounded-3xl border border-edge bg-white p-4 shadow-sm animate-fade-up">
        <div className="relative min-w-48 flex-1">
          <Search size={16} className="absolute left-3.5 top-1/2 -translate-y-1/2 text-ink-muted" aria-hidden="true" />
          <input
            value={searchTerm}
            onChange={(event) => setSearchTerm(event.target.value)}
            placeholder="Search parts by name or description..."
            className={searchInputStyle}
          />
        </div>

        <div className="flex items-center gap-1 rounded-2xl border border-edge bg-primary-light/50 p-1">
          {(['all', 'visible', 'hidden'] as const).map((status) => (
            <button
              key={status}
              type="button"
              onClick={() => setStatusFilter(status)}
              className={filterButton(statusFilter === status)}
            >
              {status === 'all' ? 'All' : status === 'visible' ? 'Visible' : 'Hidden'}
            </button>
          ))}
        </div>

        <div className="flex items-center gap-1 rounded-2xl border border-edge bg-primary-light/50 p-1">
          <button type="button" onClick={() => setView('grid')} className={filterButton(view === 'grid')}>
            <LayoutGrid size={14} /> Grid
          </button>
          <button type="button" onClick={() => setView('table')} className={filterButton(view === 'table')}>
            <List size={14} /> Table
          </button>
        </div>
      </div>

      {isLoading ? (
        <div className={`${tableCard} animate-fade-up`}>
          <div className={tableEmpty}>
            <div className={tableSpinner} aria-label="Loading..." />
            <p className="m-0">Loading spare parts...</p>
          </div>
        </div>
      ) : filteredParts.length === 0 ? (
        <div className="rounded-3xl border-2 border-dashed border-edge bg-white py-20 text-center animate-fade-up">
          <Package size={40} className="mx-auto mb-3 text-primary opacity-40" aria-hidden="true" />
          <h3 className="m-0 font-display text-xl font-black text-ink">No spare parts found</h3>
          <p className="mt-1 text-sm text-ink-muted">Try another search or visibility filter.</p>
        </div>
      ) : view === 'table' ? (
        <div className={`${tableCard} animate-fade-up`}>
          <div className={tableScroll}>
            <table className={dataTable}>
              <thead>
                <tr>
                  <th className={thCell}>ID</th>
                  <th className={thCell}>Product</th>
                  <th className={thCell}>Category</th>
                  <th className={thCell}>Price</th>
                  <th className={thCell}>Status</th>
                  <th className={`${thCell} text-right`}>Actions</th>
                </tr>
              </thead>
              <tbody className="[&>tr:last-child>td]:border-b-0">
                {paginatedParts.map((part) => (
                  <tr key={part.id} className={`${tableRow} ${!part.isActive ? 'bg-stone-50 opacity-70' : ''}`}>
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
                      <span className={badgeNeutral}>{part.categoryName || 'Uncategorized'}</span>
                    </td>
                    <td className={tdCell}>
                      <span className={badgeSuccess}>{part.price.toLocaleString('vi-VN')} VNĐ</span>
                    </td>
                    <td className={tdCell}>
                      <span className={part.isActive ? badgeSuccess : badgeNeutral}>
                        {part.isActive ? 'Visible' : 'Hidden'}
                      </span>
                    </td>
                    <td className={tdCell}>
                      <div className="flex items-center justify-end gap-1.5 opacity-70 transition-opacity hover:opacity-100">
                        <button type="button" className={iconBtnEdit} onClick={() => handleOpenModal(part)} title="Edit">
                          <Wrench size={15} />
                        </button>
                        {visibilityButton(part)}
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      ) : (
        <div className="grid grid-cols-1 gap-5 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 animate-fade-up">
          {paginatedParts.map((part) => (
            <div
              key={part.id}
              className={`group flex flex-col overflow-hidden rounded-3xl border border-edge bg-white transition-all duration-300 hover:-translate-y-1 hover:border-primary hover:shadow-[0_10px_35px_rgba(249,115,22,0.12)] ${
                !part.isActive ? 'opacity-65 grayscale-[35%]' : ''
              }`}
            >
              <div className="relative h-48 w-full border-b border-edge bg-primary-light/20">
                {part.imageUrl ? (
                  <img src={part.imageUrl} alt={part.name} className="h-full w-full object-cover" />
                ) : (
                  <div className="flex h-full w-full items-center justify-center">
                    <Package size={48} className="text-primary/30" />
                  </div>
                )}
                <div className="absolute right-3 top-3">
                  <span className={`${badgeSuccess} shadow-md`}>{part.price.toLocaleString('vi-VN')} VNĐ</span>
                </div>
              </div>

              <div className="flex flex-1 flex-col p-5">
                <div className="mb-2 flex flex-wrap items-center gap-2">
                  <span className={badgeNeutral}>{part.categoryName || 'Uncategorized'}</span>
                  <span className={part.isActive ? badgeSuccess : badgeNeutral}>
                    {part.isActive ? 'Visible' : 'Hidden'}
                  </span>
                </div>
                <h3 className="m-0 mb-1.5 font-display text-lg font-black leading-tight text-ink">{part.name}</h3>
                <p className="m-0 mb-4 line-clamp-2 text-sm text-ink-muted">
                  {part.description || 'No description available.'}
                </p>
                <div className="mt-auto flex items-center justify-between border-t border-edge pt-4">
                  <span className="text-xs text-ink-muted/70">ID: #{part.id}</span>
                  <div className="flex gap-1.5">
                    <button type="button" className={iconBtnEdit} onClick={() => handleOpenModal(part)} title="Edit">
                      <Wrench size={15} />
                    </button>
                    {visibilityButton(part)}
                  </div>
                </div>
              </div>
            </div>
          ))}
        </div>
      )}

      {totalPages > 1 && !isLoading && (
        <div className="mt-8 flex items-center justify-center gap-3 animate-fade-up">
          <button
            type="button"
            onClick={() => setCurrentPage((value) => Math.max(1, value - 1))}
            disabled={page === 1}
            className="flex h-9 w-9 items-center justify-center rounded-xl border border-edge bg-white transition hover:bg-primary-light hover:text-primary disabled:opacity-40"
          >
            <ChevronLeft size={18} />
          </button>
          <span className="text-sm font-semibold text-ink-muted">
            Page <span className="text-ink">{page}</span> of <span className="text-ink">{totalPages}</span>
          </span>
          <button
            type="button"
            onClick={() => setCurrentPage((value) => Math.min(totalPages, value + 1))}
            disabled={page === totalPages}
            className="flex h-9 w-9 items-center justify-center rounded-xl border border-edge bg-white transition hover:bg-primary-light hover:text-primary disabled:opacity-40"
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
