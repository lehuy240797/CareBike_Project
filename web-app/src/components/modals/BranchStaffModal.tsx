import { useState, useEffect } from 'react';
import { X } from 'lucide-react';
import { apiCreateStaff, apiUpdateStaff } from '../../services/staffService';
import type { StaffRecord } from '../../services/staffService';
import toast from 'react-hot-toast';
import { btnPrimary, inputBase, label } from '../../ui/styles';
import { useAuth } from '../../context/AuthContext';

interface BranchStaffModalProps {
  staff?: StaffRecord | null;
  onClose: () => void;
  onSuccess: () => void;
}

const BranchStaffModal = ({ staff, onClose, onSuccess }: BranchStaffModalProps) => {
  const { user } = useAuth();
  const branchId = (user as { branchId?: number })?.branchId;
  const isEditing = !!staff;

  const [formData, setFormData] = useState({
    fullName: staff?.fullName || '',
    phone: staff?.phone || '',
    staffCode: staff?.staffCode || '',
  });

  const [isSubmitting, setIsSubmitting] = useState(false);

  useEffect(() => {
    const originalOverflow = document.body.style.overflow;
    document.body.style.overflow = 'hidden';
    return () => {
      document.body.style.overflow = originalOverflow;
    };
  }, []);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!branchId) {
      toast.error('Branch information missing.');
      return;
    }
    
    try {
      setIsSubmitting(true);
      if (isEditing) {
        await apiUpdateStaff(staff.id, formData);
        toast.success('Mechanic updated successfully!');
      } else {
        await apiCreateStaff(branchId, formData);
        toast.success('New mechanic added successfully!');
      }
      onSuccess();
    } catch (error: any) {
      toast.error(error?.response?.data?.message || 'Action failed.');
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-stone-950/60 p-4 backdrop-blur-[3px] animate-in fade-in duration-200" onMouseDown={onClose}>
      <div 
        className="w-full max-w-lg rounded-[1.75rem] border border-edge bg-canvas shadow-float animate-in zoom-in-95 duration-200"
        onMouseDown={e => e.stopPropagation()}
      >
        <div className="flex items-center justify-between border-b border-edge bg-white px-6 py-5 rounded-t-[1.75rem]">
          <h2 className="m-0 font-display text-2xl font-black text-ink">
            {isEditing ? 'Edit Mechanic' : 'Add New Mechanic'}
          </h2>
          <button
            type="button"
            onClick={onClose}
            className="flex h-10 w-10 items-center justify-center rounded-xl bg-primary-light text-ink-muted transition hover:bg-primary hover:text-white"
          >
            <X size={20} />
          </button>
        </div>

        <form onSubmit={handleSubmit} className="px-6 py-5">
          <div className="space-y-4">
            <div>
              <label className={label}>Full Name <span className="text-red-500">*</span></label>
              <input
                type="text"
                required
                value={formData.fullName}
                onChange={e => setFormData({ ...formData, fullName: e.target.value })}
                className={inputBase}
                placeholder="E.g. John Doe"
              />
            </div>

            <div>
              <label className={label}>Phone Number</label>
              <input
                type="text"
                value={formData.phone}
                onChange={e => setFormData({ ...formData, phone: e.target.value })}
                className={inputBase}
                placeholder="E.g. 0901234567"
              />
            </div>

            <div>
              <label className={label}>Staff Code (Auto-generated if left empty)</label>
              <input
                type="text"
                value={formData.staffCode}
                onChange={e => setFormData({ ...formData, staffCode: e.target.value })}
                className={inputBase}
                placeholder="E.g. CBS-0001"
              />
            </div>
          </div>

          <div className="mt-8 flex justify-end gap-3 border-t border-edge pt-5">
            <button
              type="button"
              onClick={onClose}
              className="rounded-xl border border-edge bg-white px-5 py-2.5 text-sm font-semibold text-ink transition hover:border-primary hover:text-primary"
            >
              Cancel
            </button>
            <button
              type="submit"
              disabled={isSubmitting}
              className={`${btnPrimary} px-6 py-2.5`}
            >
              {isSubmitting ? 'Saving...' : 'Save Mechanic'}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
};

export default BranchStaffModal;
