import { useState, useEffect, useCallback } from 'react';
import { CalendarDays, Save, ChevronLeft, ChevronRight, Edit2, X } from 'lucide-react';
import { apiGetStaffByBranch, apiGetShiftsByBranch, apiUpdateShifts } from '../services/staffService';
import type { StaffRecord, ShiftRecord } from '../services/staffService';
import { useAuth } from '../context/AuthContext';
import toast from 'react-hot-toast';

// Utility functions for dates
const getStartOfWeek = (date: Date) => {
    const d = new Date(date);
    const day = d.getDay();
    const diff = d.getDate() - day + (day === 0 ? -6 : 1);
    return new Date(d.setDate(diff));
};

const formatDate = (date: Date) => {
    return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}-${String(date.getDate()).padStart(2, '0')}`;
};

const SHIFT_TYPES = [
    { value: 'MORNING', label: 'Morning (6h - 14h)', max: 4 },
    { value: 'AFTERNOON', label: 'Afternoon (14h - 22h)', max: 4 },
    { value: 'NIGHT', label: 'Night (22h - 6h)', max: 2 },
];

const BranchShiftManagement = () => {
    const { user } = useAuth();
    const branchId = (user as any)?.branchId;

    const [currentWeekStart, setCurrentWeekStart] = useState<Date>(getStartOfWeek(new Date()));
    const [staffs, setStaffs] = useState<StaffRecord[]>([]);
    const [schedule, setSchedule] = useState<Record<string, Record<string, number[]>>>({});
    const [isLoading, setIsLoading] = useState(true);
    const [isSaving, setIsSaving] = useState(false);
    const [isEditing, setIsEditing] = useState(false);

    // Calculate days for the current week
    const currentDays = Array.from({ length: 7 }).map((_, i) => {
        const d = new Date(currentWeekStart);
        d.setDate(d.getDate() + i);
        return {
            dateStr: formatDate(d),
            display: `${['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'][d.getDay()]}, ${d.getMonth() + 1}/${d.getDate()}`,
        };
    });

    const fetchData = useCallback(async () => {
        if (!branchId) return;
        setIsLoading(true);
        try {
            const startDate = formatDate(currentWeekStart);
            const endD = new Date(currentWeekStart);
            endD.setDate(endD.getDate() + 6);
            const endDate = formatDate(endD);

            const [staffData, shiftData] = await Promise.all([
                apiGetStaffByBranch(branchId),
                apiGetShiftsByBranch(branchId, startDate, endDate),
            ]);
            setStaffs(staffData);

            // Init state
            const newSchedule: Record<string, Record<string, number[]>> = {};
            currentDays.forEach(day => {
                newSchedule[day.dateStr] = {};
                SHIFT_TYPES.forEach(shift => {
                    newSchedule[day.dateStr][shift.value] = [];
                });
            });

            // Map data
            shiftData.forEach((shift: ShiftRecord) => {
                if (newSchedule[shift.shiftDate] && newSchedule[shift.shiftDate][shift.shiftType]) {
                    newSchedule[shift.shiftDate][shift.shiftType].push(shift.staff.id);
                }
            });

            setSchedule(newSchedule);
        } catch (error) {
            console.error("Error loading shift data", error);
            toast.error("Unable to load shift data.");
        } finally {
            setIsLoading(false);
        }
    }, [branchId, currentWeekStart]);

    useEffect(() => {
        fetchData();
    }, [fetchData]);

    const handleToggleStaff = (day: string, shift: string, staffId: number) => {
        setSchedule(prev => {
            const currentSelected = prev[day]?.[shift] || [];
            const isSelected = currentSelected.includes(staffId);
            const newSelected = isSelected 
                ? currentSelected.filter(id => id !== staffId)
                : [...currentSelected, staffId];

            return {
                ...prev,
                [day]: {
                    ...prev[day],
                    [shift]: newSelected
                }
            };
        });
    };

    const handleSave = async () => {
        if (!branchId) return;
        setIsSaving(true);
        try {
            const startDate = formatDate(currentWeekStart);
            const endD = new Date(currentWeekStart);
            endD.setDate(endD.getDate() + 6);
            const endDate = formatDate(endD);

            const payload: any[] = [];
            Object.keys(schedule).forEach(dateStr => {
                Object.keys(schedule[dateStr]).forEach(shift => {
                    schedule[dateStr][shift].forEach(staffId => {
                        payload.push({ staffId, shiftDate: dateStr, shiftType: shift });
                    });
                });
            });

            await apiUpdateShifts(branchId, startDate, endDate, payload);
            toast.success("Shift schedule updated successfully!");
            setIsEditing(false);
        } catch (error) {
            console.error(error);
            toast.error("Update failed.");
        } finally {
            setIsSaving(false);
        }
    };

    const changeWeek = (offset: number) => {
        const newStart = new Date(currentWeekStart);
        newStart.setDate(newStart.getDate() + (offset * 7));
        setCurrentWeekStart(newStart);
    };

    if (isLoading) {
        return <div className="dashboard-inner"><p>Loading data...</p></div>;
    }

    return (
        <div className="dashboard-inner">
            <div className="page-header" style={{ marginBottom: '1.75rem', flexWrap: 'wrap', gap: '1rem' }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: '12px', flex: 1, minWidth: '300px' }}>
                    <CalendarDays size={28} className="page-header-icon" aria-hidden="true" />
                    <div>
                        <h1 className="dashboard-title" style={{ margin: 0 }}>Shift Management</h1>
                        <p className="page-subtitle">Weekly Staff Shift Scheduling</p>
                    </div>
                </div>

                <div style={{ display: 'flex', alignItems: 'center', gap: '1rem' }}>
                    {/* Date Navigation */}
                    <div style={{ display: 'flex', alignItems: 'center', background: 'var(--color-surface)', borderRadius: '8px', border: '1px solid var(--color-border)', padding: '4px' }}>
                        <button type="button" onClick={() => changeWeek(-1)} style={{ padding: '6px', background: 'none', border: 'none', cursor: 'pointer', color: 'var(--color-text)' }}>
                            <ChevronLeft size={20} />
                        </button>
                        <span style={{ padding: '0 12px', fontWeight: 'bold' }}>
                            {formatDate(currentWeekStart)} to {formatDate(new Date(new Date(currentWeekStart).setDate(currentWeekStart.getDate() + 6)))}
                        </span>
                        <button type="button" onClick={() => changeWeek(1)} style={{ padding: '6px', background: 'none', border: 'none', cursor: 'pointer', color: 'var(--color-text)' }}>
                            <ChevronRight size={20} />
                        </button>
                    </div>

                    {isEditing ? (
                        <>
                            <button 
                                type="button" 
                                className="app-btn"
                                style={{ background: 'var(--color-surface)', color: 'var(--color-text)', border: '1px solid var(--color-border)' }}
                                onClick={() => { setIsEditing(false); fetchData(); }}
                                disabled={isSaving}
                            >
                                <X size={16} aria-hidden="true" /> Cancel
                            </button>
                            <button 
                                type="button" 
                                className="app-btn" 
                                onClick={handleSave}
                                disabled={isSaving}
                            >
                                <Save size={16} aria-hidden="true" /> {isSaving ? 'Saving...' : 'Save Shifts'}
                            </button>
                        </>
                    ) : (
                        <button 
                            type="button" 
                            className="app-btn" 
                            onClick={() => setIsEditing(true)}
                        >
                            <Edit2 size={16} aria-hidden="true" /> Edit Shifts
                        </button>
                    )}
                </div>
            </div>

            <div className="table-card">
                <div className="table-scroll" style={{ overflowX: 'auto' }}>
                    <table className="data-table" style={{ minWidth: '800px' }}>
                        <thead>
                            <tr>
                                <th style={{ width: '16%' }}>Date</th>
                                {SHIFT_TYPES.map(shift => (
                                    <th key={shift.value} style={{ width: '28%' }}>{shift.label}</th>
                                ))}
                            </tr>
                        </thead>
                        <tbody>
                            {currentDays.map(day => (
                                <tr key={day.dateStr}>
                                    <td className="font-medium" style={{ verticalAlign: 'top', paddingTop: '16px' }}>
                                        {day.display}
                                    </td>
                                    {SHIFT_TYPES.map(shift => (
                                        <td key={shift.value} style={{ verticalAlign: 'top', padding: '12px' }}>
                                            <div style={{ display: 'flex', flexDirection: 'column', gap: '8px' }}>
                                                <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '0.85rem', fontWeight: 'bold' }}>
                                                    <span style={{ color: (schedule[day.dateStr]?.[shift.value]?.length || 0) === shift.max ? 'var(--color-primary)' : 'var(--color-text-muted)' }}>
                                                        Selected: {schedule[day.dateStr]?.[shift.value]?.length || 0} / {shift.max}
                                                    </span>
                                                    {(schedule[day.dateStr]?.[shift.value]?.length || 0) !== shift.max && (
                                                        <span style={{ color: 'var(--color-error)' }}>Not enough</span>
                                                    )}
                                                </div>
                                                <div style={{ 
                                                    maxHeight: isEditing ? '160px' : 'none', 
                                                    overflowY: isEditing ? 'auto' : 'visible', 
                                                    border: isEditing ? '1px solid var(--color-border)' : '1px solid transparent', 
                                                    borderRadius: '8px', 
                                                    padding: isEditing ? '8px' : '0', 
                                                    background: isEditing ? 'var(--color-background)' : 'transparent',
                                                    display: 'flex',
                                                    flexDirection: isEditing ? 'column' : 'row',
                                                    flexWrap: isEditing ? 'nowrap' : 'wrap',
                                                    gap: '6px'
                                                }}>
                                                    {isEditing ? staffs.map(staff => {
                                                        const isSelected = (schedule[day.dateStr]?.[shift.value] || []).includes(staff.id!);
                                                        return (
                                                            <label 
                                                                key={staff.id} 
                                                                style={{ 
                                                                    display: 'flex', 
                                                                    alignItems: 'center', 
                                                                    gap: '8px', 
                                                                    cursor: 'pointer',
                                                                    padding: '4px',
                                                                    borderRadius: '4px',
                                                                    background: isSelected ? 'var(--color-primary-light, rgba(0, 123, 255, 0.1))' : 'transparent',
                                                                    transition: 'background 0.2s'
                                                                }}
                                                            >
                                                                <input 
                                                                    type="checkbox" 
                                                                    checked={isSelected}
                                                                    onChange={() => handleToggleStaff(day.dateStr, shift.value, staff.id!)}
                                                                    style={{ width: '16px', height: '16px', cursor: 'pointer', accentColor: 'var(--color-primary)' }}
                                                                />
                                                                <span style={{ fontSize: '0.9rem', color: isSelected ? 'var(--color-primary)' : 'var(--color-text)' }}>
                                                                    <strong>{staff.staffCode}</strong> - {staff.fullName}
                                                                </span>
                                                            </label>
                                                        );
                                                    }) : (
                                                        <>
                                                            {staffs.filter(s => (schedule[day.dateStr]?.[shift.value] || []).includes(s.id!)).length === 0 ? (
                                                                <span style={{ fontSize: '0.85rem', color: 'var(--color-text-muted)' }}>No staff assigned</span>
                                                            ) : staffs.filter(s => (schedule[day.dateStr]?.[shift.value] || []).includes(s.id!)).map(staff => (
                                                                <span key={staff.id} style={{
                                                                    fontSize: '0.85rem',
                                                                    background: 'var(--color-primary-light, rgba(0, 123, 255, 0.1))',
                                                                    color: 'var(--color-primary)',
                                                                    padding: '4px 8px',
                                                                    borderRadius: '4px',
                                                                    fontWeight: '500'
                                                                }}>
                                                                    {staff.staffCode} - {staff.fullName}
                                                                </span>
                                                            ))}
                                                        </>
                                                    )}
                                                </div>
                                            </div>
                                        </td>
                                    ))}
                                </tr>
                            ))}
                        </tbody>
                    </table>
                </div>
            </div>
        </div>
    );
};

export default BranchShiftManagement;
