import { useCallback, useEffect, useMemo, useState } from 'react';
import toast from 'react-hot-toast';
import { Bike, Gauge, Pencil, Plus, Search, Trash2 } from 'lucide-react';
import VehicleTireSpecModal from '../components/modals/VehicleTireSpecModal';
import {
  deleteVehicleTireSpec,
  getVehicleTireSpecs,
  type VehicleTireSpec,
} from '../services/vehicleTireSpecService';
import {
  badgeNeutral,
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

const searchInputStyle =
  'w-full rounded-2xl border border-edge bg-primary-light/40 py-2.5 pl-10 pr-4 text-sm outline-none transition-all focus:border-primary focus:ring-2 focus:ring-primary/20';

const vehicleTypeLabel = (type: string) => {
  switch (type) {
    case 'XE_TAY_GA':
      return 'Scooter';
    case 'XE_SO':
      return 'Manual';
    case 'XE_CON_TAY':
      return 'Clutch';
    default:
      return type || 'Unknown';
  }
};

const VehicleTireSpecManagement = () => {
  const [specs, setSpecs] = useState<VehicleTireSpec[]>([]);
  const [searchTerm, setSearchTerm] = useState('');
  const [selectedSpec, setSelectedSpec] = useState<VehicleTireSpec | null>(null);
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [isLoading, setIsLoading] = useState(true);

  const fetchSpecs = useCallback(async () => {
    try {
      setIsLoading(true);
      const data = await getVehicleTireSpecs();
      setSpecs(data);
    } catch (error) {
      console.error(error);
      toast.error('Error loading tire specifications');
    } finally {
      setIsLoading(false);
    }
  }, []);

  useEffect(() => {
    fetchSpecs();
  }, [fetchSpecs]);

  const filteredSpecs = useMemo(() => {
    const term = searchTerm.trim().toLowerCase();
    if (!term) return specs;
    return specs.filter((spec) =>
      [
        spec.brand,
        spec.vehicleName,
        spec.vehicleType,
        spec.frontTireSize,
        spec.rearTireSize,
        spec.engineCapacity?.toString() ?? '',
      ]
        .join(' ')
        .toLowerCase()
        .includes(term),
    );
  }, [searchTerm, specs]);

  const openCreate = () => {
    setSelectedSpec(null);
    setIsModalOpen(true);
  };

  const openEdit = (spec: VehicleTireSpec) => {
    setSelectedSpec(spec);
    setIsModalOpen(true);
  };

  const closeModal = () => {
    setSelectedSpec(null);
    setIsModalOpen(false);
  };

  const handleDelete = async (id: number) => {
    if (!window.confirm('Delete this tire specification?')) return;

    try {
      await deleteVehicleTireSpec(id);
      toast.success('Tire specification deleted');
      fetchSpecs();
    } catch (error) {
      console.error(error);
      toast.error('Could not delete tire specification');
    }
  };

  return (
    <div className="mx-auto max-w-[80rem]">
      <div className="mb-8 flex flex-col items-start justify-between gap-4 animate-fade-up sm:flex-row sm:items-center">
        <div>
          <p className={eyebrow}>Vehicle Data</p>
          <h1 className={`${dashTitle} mt-1`}>Tire Specifications</h1>
          <p className={pageSubtitle}>
            Manage front and rear tire sizes used for AI inspection estimates.
          </p>
          <p className="mt-2 max-w-3xl text-sm text-ink-muted">
            Use a specific engine capacity when tire sizes differ by variant. Leave it empty only
            when the same tire sizes apply to every engine version of that model.
          </p>
        </div>
        <button type="button" onClick={openCreate} className={btnPrimary}>
          <Plus size={18} /> Add Specification
        </button>
      </div>

      <div className="mb-6 flex items-center rounded-3xl border border-edge bg-white p-4 shadow-sm animate-fade-up" style={{ animationDelay: '0.1s' }}>
        <div className="relative w-full">
          <Search size={16} className="absolute left-3.5 top-1/2 -translate-y-1/2 text-ink-muted" aria-hidden="true" />
          <input
            value={searchTerm}
            onChange={(event) => setSearchTerm(event.target.value)}
            placeholder="Search by brand, model, size, or engine capacity..."
            className={searchInputStyle}
          />
        </div>
      </div>

      <div className={`${tableCard} animate-fade-up`} style={{ animationDelay: '0.2s' }}>
        {isLoading ? (
          <div className={tableEmpty}>
            <div className={tableSpinner} aria-label="Loading..." />
            <p className="m-0">Loading tire specifications...</p>
          </div>
        ) : filteredSpecs.length === 0 ? (
          <div className="rounded-3xl border-2 border-dashed border-edge bg-white py-20 text-center">
            <Gauge size={40} className="mx-auto mb-3 text-primary opacity-40" aria-hidden="true" />
            <h3 className="m-0 font-display text-xl font-black text-ink">No tire specifications found</h3>
            <p className="mt-1 text-sm text-ink-muted">
              Add the first vehicle tire specification to enable replacement estimates.
            </p>
          </div>
        ) : (
          <div className={tableScroll}>
            <table className={dataTable}>
              <thead>
                <tr>
                  <th className={thCell}>Vehicle</th>
                  <th className={thCell}>Type</th>
                  <th className={thCell}>Engine</th>
                  <th className={thCell}>Front Tire</th>
                  <th className={thCell}>Rear Tire</th>
                  <th className={thCell}>Note</th>
                  <th className={`${thCell} text-right`}>Actions</th>
                </tr>
              </thead>
              <tbody className="[&>tr:last-child>td]:border-b-0">
                {filteredSpecs.map((spec) => (
                  <tr key={spec.id} className={tableRow}>
                    <td className={tdCell}>
                      <div className="flex items-center gap-3">
                        <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-xl bg-primary-light text-primary">
                          <Bike size={19} aria-hidden="true" />
                        </div>
                        <div>
                          <div className="font-semibold">{spec.brand} {spec.vehicleName}</div>
                          <div className="text-xs text-ink-muted">ID: #{spec.id}</div>
                        </div>
                      </div>
                    </td>
                    <td className={tdCell}>
                      <span className={badgeNeutral}>{vehicleTypeLabel(spec.vehicleType)}</span>
                    </td>
                    <td className={`${tdCell} text-ink-muted`}>
                      {spec.engineCapacity ? `${spec.engineCapacity} cc` : 'All engines'}
                    </td>
                    <td className={`${tdCell} font-semibold`}>{spec.frontTireSize}</td>
                    <td className={`${tdCell} font-semibold`}>{spec.rearTireSize}</td>
                    <td className={`${tdCell} max-w-[240px] truncate text-ink-muted`} title={spec.note ?? ''}>
                      {spec.note || '-'}
                    </td>
                    <td className={tdCell}>
                      <div className="flex items-center justify-end gap-1.5">
                        <button
                          type="button"
                          className={iconBtnEdit}
                          onClick={() => openEdit(spec)}
                          title="Edit"
                        >
                          <Pencil size={15} />
                        </button>
                        <button
                          type="button"
                          className={iconBtnDelete}
                          onClick={() => handleDelete(spec.id)}
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
        )}
      </div>

      <VehicleTireSpecModal
        isOpen={isModalOpen}
        spec={selectedSpec}
        onClose={closeModal}
        onSuccess={fetchSpecs}
      />
    </div>
  );
};

export default VehicleTireSpecManagement;
