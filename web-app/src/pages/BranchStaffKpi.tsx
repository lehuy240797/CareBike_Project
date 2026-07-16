import { useCallback, useEffect, useMemo, useState } from 'react';
import {
  BarChart3,
  CalendarCheck2,
  RefreshCw,
  ShieldAlert,
  Trophy,
  Users,
  Wrench,
} from 'lucide-react';
import toast from 'react-hot-toast';
import { useAuth } from '../context/AuthContext';
import { useWebSocketEvent } from '../context/WebSocketContext';
import { apiGetStaffKpis } from '../services/staffKpiService';
import type { StaffKpiRecord } from '../services/staffKpiService';
import {
  btnOutline,
  dashTitle,
  dataTable,
  eyebrow,
  tableCard,
  tableEmpty,
  tableRow,
  tableScroll,
  tableSpinner,
  tdCell,
  thCell,
} from '../ui/styles';

const summaryCards = [
  { key: 'total', label: 'Completed jobs', icon: Wrench, className: 'bg-orange-50 text-primary' },
  { key: 'appointments', label: 'Appointments', icon: CalendarCheck2, className: 'bg-blue-50 text-blue-600' },
  { key: 'rescues', label: 'Rescues', icon: ShieldAlert, className: 'bg-red-50 text-red-600' },
  { key: 'staff', label: 'Mechanics', icon: Users, className: 'bg-emerald-50 text-emerald-600' },
] as const;
const monthOptions = [
  { value: '01', label: 'January' },
  { value: '02', label: 'February' },
  { value: '03', label: 'March' },
  { value: '04', label: 'April' },
  { value: '05', label: 'May' },
  { value: '06', label: 'June' },
  { value: '07', label: 'July' },
  { value: '08', label: 'August' },
  { value: '09', label: 'September' },
  { value: '10', label: 'October' },
  { value: '11', label: 'November' },
  { value: '12', label: 'December' },
];

const currentYear = new Date().getFullYear();
const yearOptions = Array.from({ length: 10 }, (_, index) => String(currentYear - index));

const BranchStaffKpi = () => {
  const { user } = useAuth();
  const branchId = user?.branchId;
  const [records, setRecords] = useState<StaffKpiRecord[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [isRefreshing, setIsRefreshing] = useState(false);
  const [filterDate, setFilterDate] = useState('');
  const [filterMonth, setFilterMonth] = useState('');
  const [filterYear, setFilterYear] = useState('');

  const filterRange = useMemo(() => {
    if (filterDate) {
      return { from: filterDate, to: filterDate };
    }
    if (!filterYear) {
      return {};
    }
    if (!filterMonth) {
      return { from: `${filterYear}-01-01`, to: `${filterYear}-12-31` };
    }

    const lastDay = new Date(Number(filterYear), Number(filterMonth), 0).getDate();
    return {
      from: `${filterYear}-${filterMonth}-01`,
      to: `${filterYear}-${filterMonth}-${String(lastDay).padStart(2, '0')}`,
    };
  }, [filterDate, filterMonth, filterYear]);

  const hasActiveFilter = Boolean(filterDate || filterMonth || filterYear);

  const fetchKpis = useCallback(async (background = false) => {
    if (!branchId) {
      setIsLoading(false);
      return;
    }

    try {
      if (background) setIsRefreshing(true);
      else setIsLoading(true);
      setRecords(await apiGetStaffKpis(branchId, filterRange));
    } catch (error) {
      console.error('Failed to load staff KPI data', error);
      toast.error('Failed to load staff KPI data.');
    } finally {
      setIsLoading(false);
      setIsRefreshing(false);
    }
  }, [branchId, filterRange]);

  useEffect(() => {
    void fetchKpis();
  }, [fetchKpis]);

  useWebSocketEvent('APPOINTMENT_UPDATED', () => void fetchKpis(true));
  useWebSocketEvent('RESCUE_UPDATED', () => void fetchKpis(true));
  useWebSocketEvent('STAFF_UPDATED', () => void fetchKpis(true));

  const totals = useMemo(() => records.reduce(
    (result, item) => ({
      appointments: result.appointments + item.completedAppointments,
      rescues: result.rescues + item.completedRescues,
      total: result.total + item.totalCompleted,
      staff: result.staff + 1,
    }),
    { appointments: 0, rescues: 0, total: 0, staff: 0 },
  ), [records]);

  const maxCompleted = Math.max(1, ...records.map((item) => item.totalCompleted));

  return (
    <div className="mx-auto max-w-[80rem]">
      <div className="mb-8 flex flex-wrap items-start justify-between gap-4 animate-fade-up">
        <div>
          <p className={eyebrow}>Performance Overview</p>
          <h1 className={`${dashTitle} mt-1`}>Mechanic KPI</h1>
          <p className="mt-1.5 font-pop text-sm text-ink-muted">
            Completed appointment and rescue jobs by mechanic.
          </p>
        </div>
        <button
          type="button"
          className={btnOutline}
          disabled={isRefreshing}
          onClick={() => void fetchKpis(true)}
        >
          <RefreshCw size={16} className={isRefreshing ? 'animate-spin' : ''} aria-hidden="true" />
          Refresh
        </button>
      </div>
      <div className="mb-7 rounded-3xl border border-edge bg-white p-4 shadow-sm">
        <div className="mb-3">
          <h2 className="m-0 font-display text-base font-black text-ink">Filter completed jobs</h2>
          <p className="m-0 mt-1 text-xs text-ink-muted">
            Choose an exact date, or combine month and year. Leave all fields empty to show all time.
          </p>
        </div>
        <div className="grid gap-3 md:grid-cols-[minmax(180px,1fr)_minmax(150px,1fr)_minmax(130px,1fr)_auto]">
          <label className="flex flex-col gap-1.5 text-xs font-semibold text-ink-muted">
            Exact date
            <input
              type="date"
              value={filterDate}
              onChange={(event) => {
                setFilterDate(event.target.value);
                setFilterMonth('');
                setFilterYear('');
              }}
              className="h-11 rounded-xl border border-edge bg-white px-3 text-sm text-ink outline-none focus:border-primary focus:ring-2 focus:ring-primary/20"
            />
          </label>
          <label className="flex flex-col gap-1.5 text-xs font-semibold text-ink-muted">
            Month
            <select
              value={filterMonth}
              onChange={(event) => {
                const month = event.target.value;
                setFilterDate('');
                setFilterMonth(month);
                if (month && !filterYear) setFilterYear(String(currentYear));
              }}
              className="h-11 rounded-xl border border-edge bg-white px-3 text-sm text-ink outline-none focus:border-primary focus:ring-2 focus:ring-primary/20"
            >
              <option value="">All months</option>
              {monthOptions.map((month) => (
                <option key={month.value} value={month.value}>{month.label}</option>
              ))}
            </select>
          </label>
          <label className="flex flex-col gap-1.5 text-xs font-semibold text-ink-muted">
            Year
            <select
              value={filterYear}
              onChange={(event) => {
                const year = event.target.value;
                setFilterDate('');
                setFilterYear(year);
                if (!year) setFilterMonth('');
              }}
              className="h-11 rounded-xl border border-edge bg-white px-3 text-sm text-ink outline-none focus:border-primary focus:ring-2 focus:ring-primary/20"
            >
              <option value="">All years</option>
              {yearOptions.map((year) => (
                <option key={year} value={year}>{year}</option>
              ))}
            </select>
          </label>
          <div className="flex items-end">
            <button
              type="button"
              disabled={!hasActiveFilter}
              onClick={() => {
                setFilterDate('');
                setFilterMonth('');
                setFilterYear('');
              }}
              className="h-11 w-full rounded-xl border border-edge bg-white px-4 text-sm font-semibold text-ink-muted transition hover:bg-primary-light hover:text-primary disabled:cursor-not-allowed disabled:opacity-50 md:w-auto"
            >
              Clear filter
            </button>
          </div>
        </div>
      </div>

      <div className="mb-7 grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
        {summaryCards.map(({ key, label, icon: Icon, className }) => (
          <div key={key} className="rounded-3xl border border-edge bg-white p-5 shadow-sm">
            <div className={`mb-5 inline-flex h-11 w-11 items-center justify-center rounded-2xl ${className}`}>
              <Icon size={21} aria-hidden="true" />
            </div>
            <p className="m-0 font-display text-3xl font-black tabular-nums text-ink">{totals[key]}</p>
            <p className="mb-0 mt-1 text-sm font-medium text-ink-muted">{label}</p>
          </div>
        ))}
      </div>

      {isLoading ? (
        <div className={tableCard}>
          <div className={tableEmpty}>
            <div className={tableSpinner} aria-label="Loading KPI data..." />
            <p className="m-0">Loading KPI data...</p>
          </div>
        </div>
      ) : records.length === 0 ? (
        <div className="rounded-3xl border-2 border-dashed border-edge bg-white py-20 text-center">
          <BarChart3 size={42} className="mx-auto mb-3 text-primary opacity-40" aria-hidden="true" />
          <h3 className="m-0 font-display text-xl font-black text-ink">No mechanics found</h3>
          <p className="mt-1 text-sm text-ink-muted">Add mechanics to this branch to start tracking KPI.</p>
        </div>
      ) : (
        <div className="space-y-7">
          <section className="rounded-3xl border border-edge bg-white p-5 shadow-sm md:p-6">
            <div className="mb-5 flex items-center gap-3">
              <div className="flex h-10 w-10 items-center justify-center rounded-2xl bg-primary-light text-primary">
                <BarChart3 size={20} aria-hidden="true" />
              </div>
              <div>
                <h2 className="m-0 font-display text-xl font-black text-ink">Completed jobs comparison</h2>
                <p className="m-0 mt-1 text-sm text-ink-muted">Automatically updated after a job is completed.</p>
              </div>
            </div>

            {totals.total === 0 ? (
              <div className="flex min-h-64 items-center justify-center rounded-2xl bg-stone-50 text-center text-sm text-ink-muted">
                No completed jobs yet.
              </div>
            ) : (
              <div>
                <div className="mb-6 flex flex-wrap justify-end gap-4 text-xs font-semibold text-ink-muted">
                  <span className="inline-flex items-center gap-2">
                    <span className="h-2.5 w-2.5 rounded-full bg-blue-500" />
                    Appointments
                  </span>
                  <span className="inline-flex items-center gap-2">
                    <span className="h-2.5 w-2.5 rounded-full bg-red-500" />
                    Rescues
                  </span>
                </div>
                <div className="space-y-5">
                  {records.map((record) => (
                    <div
                      key={record.staffId}
                      className="grid items-center gap-2 md:grid-cols-[150px_minmax(0,1fr)_48px] md:gap-4"
                    >
                      <div className="min-w-0">
                        <p className="m-0 truncate text-sm font-bold text-ink">{record.fullName}</p>
                        <p className="m-0 mt-0.5 text-xs text-ink-muted">{record.staffCode}</p>
                      </div>
                      <div className="flex h-7 overflow-hidden rounded-full bg-stone-100">
                        <div
                          className="h-full bg-blue-500 transition-all duration-500"
                          style={{ width: `${(record.completedAppointments / maxCompleted) * 100}%` }}
                          title={`${record.completedAppointments} completed appointments`}
                        />
                        <div
                          className="h-full bg-red-500 transition-all duration-500"
                          style={{ width: `${(record.completedRescues / maxCompleted) * 100}%` }}
                          title={`${record.completedRescues} completed rescues`}
                        />
                      </div>
                      <p className="m-0 text-right font-display text-lg font-black tabular-nums text-ink">
                        {record.totalCompleted}
                      </p>
                    </div>
                  ))}
                </div>
              </div>
            )}
          </section>

          <section className={tableCard}>
            <div className="flex items-center gap-3 border-b border-edge px-5 py-4">
              <Trophy size={19} className="text-primary" aria-hidden="true" />
              <h2 className="m-0 font-display text-lg font-black text-ink">Mechanic performance ranking</h2>
            </div>
            <div className={tableScroll}>
              <table className={dataTable}>
                <thead>
                  <tr>
                    <th className={thCell}>Rank</th>
                    <th className={thCell}>Mechanic</th>
                    <th className={`${thCell} text-center`}>Appointments</th>
                    <th className={`${thCell} text-center`}>Rescues</th>
                    <th className={`${thCell} text-center`}>Total completed</th>
                  </tr>
                </thead>
                <tbody className="[&>tr:last-child>td]:border-b-0">
                  {records.map((record, index) => (
                    <tr key={record.staffId} className={tableRow}>
                      <td className={`${tdCell} w-20 font-display font-black text-primary`}>#{index + 1}</td>
                      <td className={tdCell}>
                        <p className="m-0 font-bold text-ink">{record.fullName}</p>
                        <p className="m-0 mt-0.5 text-xs font-semibold text-ink-muted">{record.staffCode}</p>
                      </td>
                      <td className={`${tdCell} text-center font-bold tabular-nums text-blue-600`}>
                        {record.completedAppointments}
                      </td>
                      <td className={`${tdCell} text-center font-bold tabular-nums text-red-600`}>
                        {record.completedRescues}
                      </td>
                      <td className={`${tdCell} text-center`}>
                        <span className="inline-flex min-w-11 justify-center rounded-full bg-primary-light px-3 py-1 font-display font-black tabular-nums text-primary">
                          {record.totalCompleted}
                        </span>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </section>
        </div>
      )}
    </div>
  );
};

export default BranchStaffKpi;
