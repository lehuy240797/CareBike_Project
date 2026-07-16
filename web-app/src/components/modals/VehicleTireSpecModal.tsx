import React, { useEffect, useState, type FormEvent } from 'react';
import toast from 'react-hot-toast';
import { Gauge } from 'lucide-react';
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
  selectBase,
} from '../../ui/styles';
import {
  createVehicleTireSpec,
  updateVehicleTireSpec,
  type VehicleTireSpec,
  type VehicleTireSpecPayload,
} from '../../services/vehicleTireSpecService';

interface Props {
  isOpen: boolean;
  spec: VehicleTireSpec | null;
  onClose: () => void;
  onSuccess: () => void;
}

const vehicleTypes = [
  { value: 'XE_TAY_GA', label: 'Scooter' },
  { value: 'XE_SO', label: 'Manual' },
  { value: 'XE_CON_TAY', label: 'Clutch' },
];

const VehicleTireSpecModal: React.FC<Props> = ({ isOpen, spec, onClose, onSuccess }) => {
  const [brand, setBrand] = useState('');
  const [vehicleName, setVehicleName] = useState('');
  const [vehicleType, setVehicleType] = useState('XE_TAY_GA');
  const [engineCapacity, setEngineCapacity] = useState<number | ''>('');
  const [frontTireSize, setFrontTireSize] = useState('');
  const [rearTireSize, setRearTireSize] = useState('');
  const [note, setNote] = useState('');
  const [isSaving, setIsSaving] = useState(false);

  useEffect(() => {
    if (spec) {
      setBrand(spec.brand);
      setVehicleName(spec.vehicleName);
      setVehicleType(spec.vehicleType);
      setEngineCapacity(spec.engineCapacity ?? '');
      setFrontTireSize(spec.frontTireSize);
      setRearTireSize(spec.rearTireSize);
      setNote(spec.note ?? '');
    } else {
      setBrand('');
      setVehicleName('');
      setVehicleType('XE_TAY_GA');
      setEngineCapacity('');
      setFrontTireSize('');
      setRearTireSize('');
      setNote('');
    }
  }, [spec, isOpen]);

  if (!isOpen) return null;

  const handleSubmit = async (event: FormEvent) => {
    event.preventDefault();

    if (!brand.trim() || !vehicleName.trim() || !frontTireSize.trim() || !rearTireSize.trim()) {
      toast.error('Please fill in all required fields');
      return;
    }

    const payload: VehicleTireSpecPayload = {
      brand: brand.trim(),
      vehicleName: vehicleName.trim(),
      vehicleType,
      engineCapacity: engineCapacity === '' ? null : Number(engineCapacity),
      frontTireSize: frontTireSize.trim(),
      rearTireSize: rearTireSize.trim(),
      note: note.trim() || null,
    };

    setIsSaving(true);
    try {
      if (spec) {
        await updateVehicleTireSpec(spec.id, payload);
        toast.success('Tire specification updated');
      } else {
        await createVehicleTireSpec(payload);
        toast.success('Tire specification created');
      }
      onSuccess();
      onClose();
    } catch (error) {
      console.error(error);
      toast.error('Could not save tire specification');
    } finally {
      setIsSaving(false);
    }
  };

  return (
    <ModalOverlay
      isOpen={isOpen}
      onClose={onClose}
      title={spec ? 'Edit Tire Specification' : 'Add Tire Specification'}
      icon={<Gauge />}
    >
      <form onSubmit={handleSubmit} className={modalForm}>
        <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
          <div className={formGroup}>
            <label className={label}>
              Brand <span className="text-red-500">*</span>
            </label>
            <input
              className={inputBase}
              value={brand}
              onChange={(event) => setBrand(event.target.value)}
              placeholder="Honda"
              required
              autoFocus
            />
          </div>

          <div className={formGroup}>
            <label className={label}>
              Vehicle Name <span className="text-red-500">*</span>
            </label>
            <input
              className={inputBase}
              value={vehicleName}
              onChange={(event) => setVehicleName(event.target.value)}
              placeholder="Airblade"
              required
            />
          </div>
        </div>

        <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
          <div className={formGroup}>
            <label className={label}>Vehicle Type</label>
            <select
              className={selectBase}
              value={vehicleType}
              onChange={(event) => setVehicleType(event.target.value)}
            >
              {vehicleTypes.map((item) => (
                <option key={item.value} value={item.value}>
                  {item.label}
                </option>
              ))}
            </select>
          </div>

          <div className={formGroup}>
            <label className={label}>Engine Capacity</label>
            <input
              type="number"
              min="0"
              className={inputBase}
              value={engineCapacity}
              onChange={(event) =>
                setEngineCapacity(event.target.value === '' ? '' : Number(event.target.value))
              }
              placeholder="160"
            />
            <p className={formHint}>
              Leave empty only when the tire sizes are the same for all engine variants.
            </p>
          </div>
        </div>

        <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
          <div className={formGroup}>
            <label className={label}>
              Front Tire Size <span className="text-red-500">*</span>
            </label>
            <input
              className={inputBase}
              value={frontTireSize}
              onChange={(event) => setFrontTireSize(event.target.value)}
              placeholder="90/80-14M/C 43P"
              required
            />
          </div>

          <div className={formGroup}>
            <label className={label}>
              Rear Tire Size <span className="text-red-500">*</span>
            </label>
            <input
              className={inputBase}
              value={rearTireSize}
              onChange={(event) => setRearTireSize(event.target.value)}
              placeholder="100/80-14"
              required
            />
          </div>
        </div>

        <div className={formGroup}>
          <label className={label}>Note</label>
          <textarea
            className={inputBase}
            rows={3}
            value={note}
            onChange={(event) => setNote(event.target.value)}
            placeholder="Optional notes about year, trim, or source..."
          />
        </div>

        <div className={modalFooter}>
          <button type="button" className={btnOutline} onClick={onClose} disabled={isSaving}>
            Cancel
          </button>
          <button type="submit" className={btnPrimary} disabled={isSaving}>
            {isSaving ? 'Saving...' : spec ? 'Save Changes' : 'Create Specification'}
          </button>
        </div>
      </form>
    </ModalOverlay>
  );
};

export default VehicleTireSpecModal;
