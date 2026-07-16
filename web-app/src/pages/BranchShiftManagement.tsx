import { useCallback, useEffect, useMemo, useState } from 'react';
import {
  AlertTriangle,
  CheckCircle,
  ChevronLeft,
  ChevronRight,
  Clock,
  Edit2,
  Save,
  Users,
  X,
} from 'lucide-react';
import toast from 'react-hot-toast';
import { apiGetStaffByBranch, apiGetShiftsByBranch, apiUpdateShifts } from '../services/staffService';
import type { StaffRecord, ShiftRecord } from '../services/staffService';
import { useAuth } from '../context/AuthContext';
import { useWebSocketEvent } from '../context/WebSocketContext';
import {
  btnOutline,
  btnPrimary,
  dashTitle,
  dataTable,
  eyebrow,
  pageSubtitle,
  tableCard,
  tableScroll,
  tdCell,
  thCell,
} from '../ui/styles';

const getStartOfWeek = (date: Date) => {
  const d = new Date(date);
  const day = d.getDay();
  const diff = d.getDate() - day + (day === 0 ? -6 : 1);
  return new Date(d.setDate(diff));
};

const formatDate = (date: Date) => {
  return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}-${String(date.getDate()).padStart(2, '0')}`;
};

const dayNames = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

const SHIFT_TYPES = [
  { value: 'MORNING', label: 'Morning', time: '06:00 - 14:00', max: 4 },
  { value: 'AFTERNOON', label: 'Afternoon', time: '14:00 - 22:00', max: 4 },
  { value: 'NIGHT', label: 'Night', time: '22:00 - 06:00', max: 2 },
];

type ScheduleState = Record<string, Record<string, number[]>>;

const BranchShiftManagement = () => {
  const { user } = useAuth();
  const branchId = (user as { branchId?: number } | null)?.branchId;

  const [currentWeekStart, setCurrentWeekStart] = useState<Date>(getStartOfWeek(new Date()));
  const [staffs, setStaffs] = useState<StaffRecord[]>([]);
  const [schedule, setSchedule] = useState<ScheduleState>({});
  const [isLoading, setIsLoading] = useState(true);
  const [isSaving, setIsSaving] = useState(false);
  const [isEditing, setIsEditing] = useState(false);

  // Active shift logic
  const [now, setNow] = useState(new Date());
  useEffect(() => {
    const timer = setInterval(() => setNow(new Date()), 60000); // update every minute
    return () => clearInterval(timer);
  }, []);

  const currentHour = now.getHours();
  const activeDate = new Date(now);
  let activeShiftValue = '';

  if (currentHour >= 6 && currentHour < 14) {
    activeShiftValue = 'MORNING';
  } else if (currentHour >= 14 && currentHour < 22) {
    activeShiftValue = 'AFTERNOON';
  } else {
    activeShiftValue = 'NIGHT';
    if (currentHour < 6) {
      activeDate.setDate(activeDate.getDate() - 1);
    }
  }
  const activeDateStr = formatDate(activeDate);

  const currentDays = useMemo(() => {
    return Array.from({ length: 7 }).map((_, i) => {
      const d = new Date(currentWeekStart);
      d.setDate(d.getDate() + i);
      return {
        dateStr: formatDate(d),
        display: `${dayNames[d.getDay()]}, ${d.getMonth() + 1}/${d.getDate()}`,
      };
    });
  }, [currentWeekStart]);

  const weekEnd = useMemo(() => {
    const end = new Date(currentWeekStart);
    end.setDate(end.getDate() + 6);
    return end;
  }, [currentWeekStart]);

  const fetchData = useCallback(async (background = false) => {
    if (!branchId) {
      if (!background) setIsLoading(false);
      return;
    }
    if (!background) setIsLoading(true);

    try {
      const startDate = formatDate(currentWeekStart);
      const endDate = formatDate(weekEnd);

      const [staffData, shiftData] = await Promise.all([
        apiGetStaffByBranch(branchId),
        apiGetShiftsByBranch(branchId, startDate, endDate),
      ]);
      setStaffs(staffData);

      const newSchedule: ScheduleState = {};
      currentDays.forEach((day) => {
        newSchedule[day.dateStr] = {};
        SHIFT_TYPES.forEach((shift) => {
          newSchedule[day.dateStr][shift.value] = [];
        });
      });

      shiftData.forEach((shift: ShiftRecord) => {
        if (newSchedule[shift.shiftDate]?.[shift.shiftType]) {
          newSchedule[shift.shiftDate][shift.shiftType].push(shift.staff.id);
        }
      });

      setSchedule(newSchedule);
    } catch (error) {
      console.error('Error loading shift data', error);
      toast.error('Unable to load shift data.');
    } finally {
      if (!background) setIsLoading(false);
    }
  }, [branchId, currentDays, currentWeekStart, weekEnd]);

  useEffect(() => {
    void Promise.resolve().then(() => fetchData());
  }, [fetchData]);

  // Auto-refresh when staff status changes via WebSocket
  useWebSocketEvent('STAFF_UPDATED', () => fetchData(true));
  useWebSocketEvent('SHIFT_UPDATED', () => fetchData(true));

  const handleToggleStaff = (day: string, shift: string, staffId: number) => {
    setSchedule((prev) => {
      const currentSelected = prev[day]?.[shift] || [];
      const isSelected = currentSelected.includes(staffId);

      if (!isSelected) {
        const shiftConfig = SHIFT_TYPES.find((s) => s.value === shift);
        if (shiftConfig && currentSelected.length >= shiftConfig.max) {
          toast.error(`This shift has already reached the maximum of ${shiftConfig.max} employees!`);
          return prev;
        }

        let shiftsCount = 0;
        SHIFT_TYPES.forEach((s) => {
          if (prev[day]?.[s.value]?.includes(staffId)) {
            shiftsCount++;
          }
        });

        if (shiftsCount >= 2) {
          toast.error('This employee has already been scheduled for the maximum of two shifts in a single day!');
          return prev;
        }
      }

      const newSelected = isSelected
        ? currentSelected.filter((id) => id !== staffId)
        : [...currentSelected, staffId];

      return {
        ...prev,
        [day]: {
          ...prev[day],
          [shift]: newSelected,
        },
      };
    });
  };

  const handleSave = async () => {
    if (!branchId) return;
    setIsSaving(true);
    try {
      const startDate = formatDate(currentWeekStart);
      const endDate = formatDate(weekEnd);

      const payload: Array<{ staffId: number; shiftDate: string; shiftType: string }> = [];
      Object.keys(schedule).forEach((dateStr) => {
        Object.keys(schedule[dateStr]).forEach((shift) => {
          schedule[dateStr][shift].forEach((staffId) => {
            payload.push({ staffId, shiftDate: dateStr, shiftType: shift });
          });
        });
      });

      await apiUpdateShifts(branchId, startDate, endDate, payload);
      toast.success('Shift schedule updated successfully!');
      setIsEditing(false);
    } catch (error) {
      console.error(error);
      toast.error('Update failed.');
    } finally {
      setIsSaving(false);
    }
  };

  const changeWeek = (offset: number) => {
    const newStart = new Date(currentWeekStart);
    newStart.setDate(newStart.getDate() + offset * 7);
    setCurrentWeekStart(newStart);
  };

  const assignedSlots = Object.values(schedule).reduce((sum, day) => {
    return sum + Object.values(day).reduce((daySum, shift) => daySum + shift.length, 0);
  }, 0);

  const targetSlots = currentDays.length * SHIFT_TYPES.reduce((sum, shift) => sum + shift.max, 0);
  const incompleteSlots = currentDays.reduce((sum, day) => {
    return sum + SHIFT_TYPES.filter((shift) => (schedule[day.dateStr]?.[shift.value]?.length || 0) !== shift.max).length;
  }, 0);

  if (isLoading) {
    return (
      <div className="dashboard-inner">
        <div className="flex min-h-[360px] items-center justify-center">
          <div className="flex flex-col items-center gap-3 text-ink-muted">
            <div className="h-9 w-9 animate-spin rounded-full border-[3px] border-edge border-t-primary" />
            <p className="font-pop text-sm font-semibold">Loading shift schedule...</p>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="dashboard-inner space-y-6">
      <div className="flex flex-wrap items-start justify-between gap-4">
        <div>
          <p className={eyebrow}>Schedule</p>
          <h1 className={dashTitle}>Shift Schedule</h1>
          <p className={pageSubtitle}>Plan weekly branch coverage and balance staff assignments.</p>
        </div>

        <div className="flex flex-wrap items-center justify-end gap-3">
          <div className="inline-flex items-center gap-2 rounded-2xl border border-edge bg-white p-1 shadow-soft">
            <button
              type="button"
              onClick={() => changeWeek(-1)}
              className="inline-flex h-10 w-10 items-center justify-center rounded-xl text-ink-muted transition hover:bg-primary-light hover:text-primary"
              aria-label="Previous week"
            >
              <ChevronLeft size={20} aria-hidden="true" />
            </button>
            <span className="min-w-[210px] px-2 text-center font-pop text-sm font-bold text-ink">
              {formatDate(currentWeekStart)} to {formatDate(weekEnd)}
            </span>
            <button
              type="button"
              onClick={() => changeWeek(1)}
              className="inline-flex h-10 w-10 items-center justify-center rounded-xl text-ink-muted transition hover:bg-primary-light hover:text-primary"
              aria-label="Next week"
            >
              <ChevronRight size={20} aria-hidden="true" />
            </button>
          </div>

          {isEditing ? (
            <>
              <button
                type="button"
                className={btnOutline}
                onClick={() => {
                  setIsEditing(false);
                  fetchData();
                }}
                disabled={isSaving}
              >
                <X size={16} aria-hidden="true" /> Cancel
              </button>
              <button type="button" className={btnPrimary} onClick={handleSave} disabled={isSaving}>
                <Save size={16} aria-hidden="true" /> {isSaving ? 'Saving...' : 'Save Shifts'}
              </button>
            </>
          ) : (
            <button type="button" className={btnPrimary} onClick={() => setIsEditing(true)}>
              <Edit2 size={16} aria-hidden="true" /> Edit Shifts
            </button>
          )}
        </div>
      </div>

      <div className="grid grid-cols-1 gap-4 md:grid-cols-3">
        <SummaryCard title="Branch staff" value={staffs.length.toString()} icon={<Users size={27} aria-hidden="true" />} tone="primary" />
        <SummaryCard title="Assigned slots" value={assignedSlots.toString()} subtitle={`Target ${targetSlots}`} icon={<Clock size={27} aria-hidden="true" />} tone="amber" />
        <SummaryCard
          title="Coverage"
          value={incompleteSlots === 0 ? 'OK' : incompleteSlots.toString()}
          subtitle={incompleteSlots === 0 ? 'All shifts fully staffed' : 'Shifts need attention'}
          icon={incompleteSlots === 0 ? <CheckCircle size={27} aria-hidden="true" /> : <AlertTriangle size={27} aria-hidden="true" />}
          tone={incompleteSlots === 0 ? 'success' : 'danger'}
        />
      </div>

      <div className={tableCard}>
        <div className={tableScroll}>
          <table className={`${dataTable} min-w-[980px]`}>
            <thead>
              <tr className="divide-x divide-black">
                <th className={`${thCell} !border-black !bg-orange-200 !text-ink !font-black text-[0.8rem] !text-center`} style={{ width: '16%' }}>Date</th>
                {SHIFT_TYPES.map((shift) => (
                  <th key={shift.value} className={`${thCell} !border-black !bg-orange-200 !text-ink !font-black !text-center`} style={{ width: '28%' }}>
                    <div className="flex flex-col items-center gap-1">
                      <span className="text-[0.8rem]">{shift.label}</span>
                      <span className="font-pop text-[0.75rem] font-bold normal-case tracking-normal !text-ink">{shift.time}</span>
                    </div>
                  </th>
                ))}
              </tr>
            </thead>
            <tbody>
              {currentDays.map((day, rowIndex) => (
                <tr key={day.dateStr} className="divide-x divide-black transition-colors hover:bg-primary-light/50">
                  <td className={`${tdCell} !border-black align-top !bg-orange-200`}>
                    <div className="flex flex-col items-center justify-center gap-1 h-full pt-2">
                      <span className="font-pop text-sm font-extrabold text-ink !text-center">{day.display}</span>
                      <span className="font-orb text-[0.65rem] !font-black uppercase tracking-[1.8px] !text-ink !text-center">{day.dateStr}</span>
                    </div>
                  </td>
                  {SHIFT_TYPES.map((shift, colIndex) => {
                    const selectedIds = schedule[day.dateStr]?.[shift.value] || [];
                    const selectedStaff = staffs.filter((staff) => selectedIds.includes(staff.id!));
                    const isFull = selectedIds.length === shift.max;
                    
                    // Checkerboard pattern for assignment cells
                    const isOrange = (rowIndex + colIndex) % 2 === 0;
                    const isCurrentActiveShift = day.dateStr === activeDateStr && shift.value === activeShiftValue;

                    let cellBg = isOrange ? 'bg-orange-50/50' : 'bg-white';
                    if (isCurrentActiveShift) {
                      cellBg = 'bg-yellow-200 shadow-[inset_0_0_0_3px_#eab308] relative z-10';
                    }

                    return (
                      <td key={shift.value} className={`${tdCell} !border-black align-top ${cellBg}`}>
                        {isCurrentActiveShift && (
                          <div className="absolute -top-3 left-1/2 -translate-x-1/2 rounded-full bg-yellow-500 px-2 py-0.5 text-[0.65rem] font-black uppercase text-white shadow-sm">
                            Active Now
                          </div>
                        )}
                        <div className="flex flex-col gap-3">
                          <div className="flex items-center justify-between gap-2 text-[0.82rem] font-bold">
                            <span className={isFull ? 'text-primary' : 'text-ink-muted'}>
                              Selected: {selectedIds.length} / {shift.max}
                            </span>
                            {!isFull && (
                              <span className="rounded-full bg-red-50 px-2 py-0.5 text-[0.72rem] font-extrabold text-red-600">Need more</span>
                            )}
                          </div>

                          <div className={isEditing ? 'flex max-h-44 flex-col gap-2 overflow-y-auto rounded-2xl border border-edge bg-canvas p-2' : 'flex flex-col items-center gap-2'}>
                            {isEditing ? (
                              staffs.map((staff) => {
                                const isSelected = selectedIds.includes(staff.id!);
                                return (
                                  <label
                                    key={staff.id}
                                    className={`flex cursor-pointer items-center gap-2 rounded-xl px-3 py-2 transition ${isSelected ? 'bg-primary-muted text-primary-deep' : 'text-ink hover:bg-white'}`}
                                  >
                                    <input
                                      type="checkbox"
                                      checked={isSelected}
                                      onChange={() => handleToggleStaff(day.dateStr, shift.value, staff.id!)}
                                      className="h-4 w-4 cursor-pointer accent-primary"
                                    />
                                    <span className="text-sm">
                                      <strong>{staff.staffCode}</strong> - {staff.fullName}
                                      <span className={`ml-2 inline-flex items-center gap-1 rounded-full px-1.5 py-0.5 text-[10px] font-bold ${
                                        staff.status === 'BUSY' ? 'bg-red-50 text-red-600' : 'bg-green-50 text-green-700'
                                      }`}>
                                        <span className={`h-1 w-1 rounded-full ${staff.status === 'BUSY' ? 'bg-red-500' : 'bg-green-500'}`}></span>
                                        {staff.status === 'BUSY' ? 'Busy' : 'Free'}
                                      </span>
                                    </span>
                                  </label>
                                );
                              })
                            ) : selectedStaff.length === 0 ? (
                              <span className="rounded-xl border border-dashed border-edge bg-canvas px-3 py-2 text-sm font-semibold text-ink-muted text-center w-full block">
                                No staff assigned
                              </span>
                            ) : (
                              selectedStaff.map((staff) => (
                                <span key={staff.id} className="inline-flex items-center gap-1.5 rounded-full bg-primary-light px-3 py-1 text-sm font-bold text-primary-deep">
                                  {staff.staffCode} - {staff.fullName}
                                  <span className={`inline-flex items-center gap-1 rounded-full px-1.5 py-0.5 text-[10px] font-bold ${
                                    staff.status === 'BUSY' ? 'bg-red-100 text-red-600' : 'bg-green-100 text-green-700'
                                  }`}>
                                    <span className={`h-1 w-1 rounded-full ${staff.status === 'BUSY' ? 'bg-red-500' : 'bg-green-500'}`}></span>
                                    {staff.status === 'BUSY' ? 'Busy' : 'Free'}
                                  </span>
                                </span>
                              ))
                            )}
                          </div>
                        </div>
                      </td>
                    );
                  })}
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
};

const SummaryCard = ({
  title,
  value,
  subtitle,
  icon,
  tone,
}: {
  title: string;
  value: string;
  subtitle?: string;
  icon: React.ReactNode;
  tone: 'primary' | 'amber' | 'success' | 'danger';
}) => {
  const toneClass = {
    primary: 'bg-primary-light text-primary',
    amber: 'bg-amber-50 text-primary-deep',
    success: 'bg-green-50 text-green-700',
    danger: 'bg-red-50 text-red-600',
  }[tone];

  return (
    <div className="rounded-3xl border border-edge bg-white p-6 shadow-card">
      <div className="flex items-center justify-between gap-4">
        <div>
          <p className="font-pop text-sm font-semibold text-ink-muted">{title}</p>
          <p className="mt-1 font-display text-4xl font-black text-ink">{value}</p>
          {subtitle && <p className="mt-1 text-xs font-semibold text-ink-muted">{subtitle}</p>}
        </div>
        <div className={`flex h-14 w-14 items-center justify-center rounded-2xl ${toneClass}`}>
          {icon}
        </div>
      </div>
    </div>
  );
};

export default BranchShiftManagement;

