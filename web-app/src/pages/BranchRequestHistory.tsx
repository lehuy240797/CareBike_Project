import { Fragment, useCallback, useEffect, useMemo, useState } from "react";
import type { ReactNode } from "react";
import { createPortal } from "react-dom";
import {
  AlertTriangle,
  Bike,
  CalendarDays,
  CheckCircle,
  Clock,
  FileText,
  History,
  Phone,
  Printer,
  ReceiptText,
  RefreshCw,
  Search,
  Download,
  UserRound,
  Wrench,
  X,
  XCircle,
  type LucideIcon,
} from "lucide-react";
import toast from "react-hot-toast";
import apiClient from "../services/apiClient";
import { getMaintenanceByCustomer } from "../services/maintenanceService";
import { useAuth } from "../context/AuthContext";
import { useWebSocketEvent } from "../context/WebSocketContext";
import {
  dashTitle,
  dataTable,
  eyebrow,
  iconBtnMaintenance,
  pageSubtitle,
  tableCard,
  tableEmpty,
  tableRow,
  tableScroll,
  tdCell,
  thCell,
} from "../ui/styles";

interface RequestRecord {
  id: number;
  type: "RESCUE" | "APPOINTMENT";
  sourceType?: "RESCUE" | "APPOINTMENT" | "WALK_IN" | string;
  status: string;
  customer?: ApiObject;
  customerName?: string;
  customerPhone?: string;
  vehicle?: ApiObject;
  vehicleName?: string;
  vehiclePlate?: string;
  branch?: ApiObject;
  branchId?: number;
  branchName?: string;
  createdAt?: string;
  appointmentDate?: string;
  invoiceDetails?: string;
  totalCost?: number;
  transportFee?: number;
  issueDescription?: string;
  distanceKm?: number;
  staffCode?: string;
  note?: string;
  appointmentInvoice?: InvoiceData;
  [key: string]: unknown;
}

type TabKey = "RESCUE" | "APPOINTMENT";
type ApiObject = Record<string, unknown>;

interface InvoiceItem {
  name?: string;
  quantity?: number;
  price?: number;
}

interface InvoiceData {
  sourceType?: "RESCUE" | "APPOINTMENT" | string;
  appointmentId?: number;
  date?: string;
  customerName?: string;
  customerPhone?: string;
  vehicleName?: string;
  vehiclePlate?: string;
  staffCode?: string;
  staffName?: string;
  laborCost?: number;
  distanceKm?: number;
  transportFee?: number;
  totalAmount?: number;
  items?: InvoiceItem[];
}

interface MaintenanceHistoryRecord {
  id: number;
  serviceDate?: string;
  serviceDetails?: string | null;
  totalCost?: number | null;
  branch?: ApiObject | null;
  branchId?: number | null;
}

const tabs: Array<{ key: TabKey; label: string; icon: LucideIcon }> = [
  { key: "RESCUE", label: "Rescues", icon: AlertTriangle },
  { key: "APPOINTMENT", label: "Appointments", icon: CalendarDays },
];

const PAGE_SIZE = 10;
const monthChoices = [
  { value: "01", label: "January" },
  { value: "02", label: "February" },
  { value: "03", label: "March" },
  { value: "04", label: "April" },
  { value: "05", label: "May" },
  { value: "06", label: "June" },
  { value: "07", label: "July" },
  { value: "08", label: "August" },
  { value: "09", label: "September" },
  { value: "10", label: "October" },
  { value: "11", label: "November" },
  { value: "12", label: "December" },
];

const BranchRequestHistory = () => {
  const { user } = useAuth();
  const branchId = (user as { branchId?: number } | null)?.branchId;

  const [activeTab, setActiveTab] = useState<TabKey>("RESCUE");
  const [rescues, setRescues] = useState<RequestRecord[]>([]);
  const [appointments, setAppointments] = useState<RequestRecord[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [searchTerm, setSearchTerm] = useState("");
  const [filterMonth, setFilterMonth] = useState("");
  const [filterYear, setFilterYear] = useState("");
  const [openFilterMenu, setOpenFilterMenu] = useState<"month" | "year" | null>(
    null,
  );
  const [page, setPage] = useState(1);
  const [selectedItem, setSelectedItem] = useState<RequestRecord | null>(null);

  const fetchData = useCallback(
    async (background = false) => {
      if (!branchId) return;
      if (!background) setIsLoading(true);

      const [rescueResult, appointmentResult, walkInResult] =
        await Promise.allSettled([
          apiClient.get(`/rescues/branch/${branchId}`),
          apiClient.get(`/appointments/branch/${branchId}`),
          apiClient.get(`/walk-in-repairs/branch/${branchId}`),
        ]);

      if (rescueResult.status === "fulfilled") {
        const rescueData = rescueResult.value.data as ApiObject[];
        const mappedRescues = rescueData.map((r) => ({
          ...r,
          type: "RESCUE",
        })) as RequestRecord[];
        mappedRescues.sort((a: RequestRecord, b: RequestRecord) => b.id - a.id);
        setRescues(mappedRescues);
      } else {
        console.error("Failed to load rescues", rescueResult.reason);
        toast.error(
          `Failed to load rescues: ${apiErrorLabel(rescueResult.reason)}`,
        );
      }

      if (appointmentResult.status === "fulfilled") {
        const appointmentData = appointmentResult.value.data as ApiObject[];
        const mappedAppointments = appointmentData.map((a) => ({
          ...a,
          type: "APPOINTMENT",
          sourceType: "APPOINTMENT",
        })) as RequestRecord[];

        let mappedWalkIns: RequestRecord[] = [];
        if (walkInResult.status === "fulfilled") {
          const walkInData = walkInResult.value.data as ApiObject[];
          mappedWalkIns = walkInData.map((record) => ({
            ...record,
            type: "APPOINTMENT",
            sourceType: "WALK_IN",
            appointmentInvoice: parseInvoice(asText(record.invoiceDetails)),
          })) as RequestRecord[];
        } else {
          console.error("Failed to load walk-in repairs", walkInResult.reason);
          toast.error(
            `Failed to load walk-in repairs: ${apiErrorLabel(walkInResult.reason)}`,
          );
        }

        const enrichedAppointments = await enrichAppointmentsWithInvoices([
          ...mappedAppointments,
          ...mappedWalkIns,
        ]);
        enrichedAppointments.sort(sortByRequestTimeDesc);
        setAppointments(enrichedAppointments);
      } else {
        console.error("Failed to load appointments", appointmentResult.reason);
        toast.error(
          `Failed to load appointments: ${apiErrorLabel(appointmentResult.reason)}`,
        );
      }

      if (!background) setIsLoading(false);
    },
    [branchId],
  );

  const refreshInBackground = useCallback(() => {
    void fetchData(true);
  }, [fetchData]);

  useWebSocketEvent("APPOINTMENT_UPDATED", refreshInBackground);
  useWebSocketEvent("RESCUE_UPDATED", refreshInBackground);
  useWebSocketEvent("MAINTENANCE_UPDATED", refreshInBackground);


  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect
    void fetchData();
  }, [fetchData]);

  const activeList = activeTab === "RESCUE" ? rescues : appointments;

  const availableYears = useMemo(() => {
    const years = activeList
      .map((item) => new Date(requestTime(item)))
      .filter((date) => !Number.isNaN(date.getTime()))
      .map((date) => String(date.getFullYear()));

    return Array.from(new Set(years)).sort((a, b) => Number(b) - Number(a));
  }, [activeList]);

  const filteredList = useMemo(() => {
    const dateFiltered =
      filterMonth || filterYear
        ? activeList.filter((item) => {
            const date = new Date(requestTime(item));
            if (Number.isNaN(date.getTime())) return false;

            const itemMonth = String(date.getMonth() + 1).padStart(2, "0");
            const itemYear = String(date.getFullYear());
            const monthMatches = !filterMonth || itemMonth === filterMonth;
            const yearMatches = !filterYear || itemYear === filterYear;

            return monthMatches && yearMatches;
          })
        : activeList;

    if (!searchTerm) return dateFiltered;
    const lowerTerm = searchTerm.toLowerCase();
    return dateFiltered.filter((item) => {
      const haystack = [
        customerName(item),
        customerPhone(item),
        vehicleName(item),
        vehiclePlate(item),
      ]
        .filter(Boolean)
        .join(" ")
        .toLowerCase();

      return haystack.includes(lowerTerm);
    });
  }, [activeList, filterMonth, filterYear, searchTerm]);

  const totalPages = Math.max(1, Math.ceil(filteredList.length / PAGE_SIZE));
  const currentPage = Math.min(page, totalPages);
  const pageStart = (currentPage - 1) * PAGE_SIZE;
  const pagedList = filteredList.slice(pageStart, pageStart + PAGE_SIZE);

  useEffect(() => {
    setPage(1);
  }, [activeTab, filterMonth, filterYear, searchTerm]);

  useEffect(() => {
    if (page > totalPages) setPage(totalPages);
  }, [page, totalPages]);

  const completedCount = activeList.filter(
    (item) => item.status === "COMPLETED",
  ).length;
  const pendingCount = activeList.filter((item) =>
    ["PENDING", "ACCEPTED", "CONFIRMED"].includes(item.status),
  ).length;
  const selectedMonthLabel =
    monthChoices.find((month) => month.value === filterMonth)?.label ||
    "All months";
  const selectedYearLabel = filterYear || "All years";

  const handleExportCSV = () => {
    if (filteredList.length === 0) {
      toast.error("No data to export!");
      return;
    }

    const headers = [
      "ID",
      "Type",
      "Customer",
      "Phone",
      "Vehicle",
      "Plate",
      "Time",
      "Status",
      "Total Cost",
    ];
    const rows = filteredList.map((item) => [
      item.id,
      item.type,
      `"${customerName(item)}"`,
      `"${customerPhone(item) || ""}"`,
      `"${vehicleName(item) || ""}"`,
      `"${vehiclePlate(item) || ""}"`,
      `"${formatDate(requestTime(item))}"`,
      item.status,
      item.type === "RESCUE"
        ? item.totalCost || item.transportFee || 0
        : item.appointmentInvoice?.totalAmount || 0,
    ]);

    const csvContent = [
      headers.join(","),
      ...rows.map((e) => e.join(",")),
    ].join("\n");
    const blob = new Blob([new Uint8Array([0xef, 0xbb, 0xbf]), csvContent], {
      type: "text/csv;charset=utf-8;",
    });
    const url = URL.createObjectURL(blob);
    const link = document.createElement("a");
    link.href = url;
    link.setAttribute(
      "download",
      `${activeTab}_history_${new Date().getTime()}.csv`,
    );
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
  };

  return (
    <div className="mx-auto max-w-[76rem] animate-fade-up">
      <div className="mb-8 flex flex-col gap-5 lg:flex-row lg:items-end lg:justify-between">
        <div>
          <p className={eyebrow}>History</p>
          <h1 className={`${dashTitle} mt-2`}>Request & Invoice History</h1>
          <p className={pageSubtitle}>
            Track rescue requests, maintenance bookings and completed invoices.
          </p>
        </div>

        <div className="flex flex-wrap items-center gap-3">
          <button
            type="button"
            onClick={handleExportCSV}
            className="inline-flex items-center justify-center gap-2 rounded-xl bg-primary px-4 py-2.5 text-sm font-semibold text-white shadow-sm transition-all duration-200 hover:-translate-y-0.5 hover:bg-primary-deep"
          >
            <Download size={16} />
            Export CSV
          </button>
          <button
            type="button"
            onClick={() => {
              void fetchData();
            }}
            className="inline-flex items-center justify-center gap-2 rounded-xl border border-edge bg-white px-4 py-2.5 text-sm font-semibold text-ink shadow-sm transition-all duration-200 hover:-translate-y-0.5 hover:border-primary hover:text-primary"
          >
            <RefreshCw size={16} />
            Refresh
          </button>
        </div>
      </div>

      <div className="mb-6 grid gap-4 md:grid-cols-3">
        <SummaryCard
          title="Total records"
          value={activeList.length}
          icon={History}
        />
        <SummaryCard
          title="In progress"
          value={pendingCount}
          icon={Clock}
          tone="amber"
        />
        <SummaryCard
          title="Completed"
          value={completedCount}
          icon={CheckCircle}
          tone="green"
        />
      </div>

      <div className="mb-5 rounded-3xl border border-edge bg-white p-4 shadow-sm">
        <div className="flex flex-col gap-3 lg:flex-row lg:items-center">
          <div className="inline-flex rounded-2xl border border-edge bg-primary-light p-1">
            {tabs.map((tab) => {
              const Icon = tab.icon;
              const active = activeTab === tab.key;
              return (
                <button
                  key={tab.key}
                  type="button"
                  onClick={() => setActiveTab(tab.key)}
                  className={`inline-flex items-center gap-2 rounded-xl px-4 py-2 text-sm font-bold transition-all duration-200 ${
                    active
                      ? "bg-primary text-white shadow-glow-sm"
                      : "text-ink-muted hover:bg-white hover:text-primary"
                  }`}
                >
                  <Icon size={16} />
                  {tab.label}
                </button>
              );
            })}
          </div>

          <div className="relative min-w-[16rem] flex-1">
            <Search
              size={18}
              className="pointer-events-none absolute left-3.5 top-1/2 -translate-y-1/2 text-ink-muted"
            />
            <input
              type="text"
              placeholder="Search customer, phone, vehicle, plate..."
              value={searchTerm}
              onChange={(event) => setSearchTerm(event.target.value)}
              className="w-full rounded-2xl border border-edge bg-white py-3 pl-11 pr-4 text-sm font-medium text-ink outline-none transition focus:border-primary focus:shadow-[0_0_0_3px_rgba(249,115,22,0.18)]"
            />
          </div>

          <div className="relative flex min-w-[22rem] items-center gap-2 rounded-2xl border border-edge bg-white px-3 py-2 shadow-sm">
            <CalendarDays size={18} className="shrink-0 text-primary" />
            <button
              type="button"
              onClick={() =>
                setOpenFilterMenu(openFilterMenu === "month" ? null : "month")
              }
              className="inline-flex min-w-0 flex-1 items-center justify-between gap-2 rounded-xl bg-primary-light px-3 py-2 text-left text-sm font-bold text-ink transition hover:bg-primary/10 focus:outline-none focus:shadow-[0_0_0_3px_rgba(249,115,22,0.18)]"
            >
              <span className="truncate">{selectedMonthLabel}</span>
              <span className="text-primary">⌄</span>
            </button>
            <button
              type="button"
              onClick={() =>
                setOpenFilterMenu(openFilterMenu === "year" ? null : "year")
              }
              className="inline-flex w-28 items-center justify-between gap-2 rounded-xl bg-primary-light px-3 py-2 text-left text-sm font-bold text-ink transition hover:bg-primary/10 focus:outline-none focus:shadow-[0_0_0_3px_rgba(249,115,22,0.18)]"
            >
              <span className="truncate">{selectedYearLabel}</span>
              <span className="text-primary">⌄</span>
            </button>
            <button
              type="button"
              onClick={() => {
                setFilterMonth("");
                setFilterYear("");
                setOpenFilterMenu(null);
              }}
              disabled={!filterMonth && !filterYear}
              className="inline-flex h-10 w-10 shrink-0 items-center justify-center rounded-xl text-ink-muted transition hover:bg-primary hover:text-white disabled:cursor-not-allowed disabled:opacity-35 disabled:hover:bg-transparent disabled:hover:text-ink-muted"
              aria-label="Clear month filter"
            >
              <X size={17} />
            </button>

            {openFilterMenu === "month" && (
              <div className="absolute left-10 top-[calc(100%+0.5rem)] z-30 w-56 overflow-hidden rounded-2xl border border-edge bg-white p-2 shadow-float">
                <button
                  type="button"
                  onClick={() => {
                    setFilterMonth("");
                    setOpenFilterMenu(null);
                  }}
                  className={`flex w-full items-center justify-center rounded-xl px-3 py-2 text-center text-sm font-bold transition ${
                    !filterMonth
                      ? "bg-primary text-white"
                      : "text-ink hover:bg-primary-light hover:text-primary"
                  }`}
                >
                  All months
                </button>
                <div className="mt-1 grid grid-cols-3 gap-1">
                  {monthChoices.map((month) => {
                    const active = filterMonth === month.value;
                    return (
                      <button
                        key={month.value}
                        type="button"
                        onClick={() => {
                          setFilterMonth(month.value);
                          setOpenFilterMenu(null);
                        }}
                        className={`rounded-xl px-3 py-2 text-center text-sm font-bold transition ${
                          active
                            ? "bg-primary text-white"
                            : "text-ink hover:bg-primary-light hover:text-primary"
                        }`}
                      >
                        {month.label.slice(0, 3)}
                      </button>
                    );
                  })}
                </div>
              </div>
            )}

            {openFilterMenu === "year" && (
              <div className="absolute right-14 top-[calc(100%+0.5rem)] z-30 max-h-72 w-40 overflow-y-auto rounded-2xl border border-edge bg-white p-2 shadow-float">
                <button
                  type="button"
                  onClick={() => {
                    setFilterYear("");
                    setOpenFilterMenu(null);
                  }}
                  className={`flex w-full items-center justify-center rounded-xl px-3 py-2 text-center text-sm font-bold transition ${
                    !filterYear
                      ? "bg-primary text-white"
                      : "text-ink hover:bg-primary-light hover:text-primary"
                  }`}
                >
                  All years
                </button>
                {availableYears.map((year) => {
                  const active = filterYear === year;
                  return (
                    <button
                      key={year}
                      type="button"
                      onClick={() => {
                        setFilterYear(year);
                        setOpenFilterMenu(null);
                      }}
                      className={`mt-1 flex w-full items-center justify-center rounded-xl px-3 py-2 text-center text-sm font-bold transition ${
                        active
                          ? "bg-primary text-white"
                          : "text-ink hover:bg-primary-light hover:text-primary"
                      }`}
                    >
                      {year}
                    </button>
                  );
                })}
              </div>
            )}
          </div>
        </div>
      </div>

      <div className={tableCard}>
        <div className={tableScroll}>
          <table className={dataTable}>
            <thead>
              <tr>
                <th className={thCell}>Request</th>
                <th className={thCell}>Customer</th>
                <th className={thCell}>Vehicle</th>
                <th className={thCell}>Time</th>
                <th className={thCell}>Status</th>
                <th className={`${thCell} text-right`}>Action</th>
              </tr>
            </thead>
            <tbody>
              {isLoading ? (
                <tr>
                  <td colSpan={6}>
                    <div className={tableEmpty}>
                      <div className="h-8 w-8 animate-spin-fast rounded-full border-[3px] border-edge border-t-primary" />
                      Loading request history...
                    </div>
                  </td>
                </tr>
              ) : filteredList.length === 0 ? (
                <tr>
                  <td colSpan={6}>
                    <div className={tableEmpty}>
                      <FileText size={34} className="text-primary" />
                      No matching records found.
                    </div>
                  </td>
                </tr>
              ) : (
                pagedList.map((item) => (
                  <tr
                    key={`${item.type}-${item.sourceType || "DEFAULT"}-${item.id}`}
                    className={tableRow}
                  >
                    <td className={tdCell}>
                      <div className="flex items-center gap-3">
                        <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-primary-light text-primary">
                          {item.type === "RESCUE" ? (
                            <AlertTriangle size={18} />
                          ) : (
                            <CalendarDays size={18} />
                          )}
                        </div>
                        <div>
                          <p className="m-0 font-bold text-ink">#{item.id}</p>
                          <p className="m-0 text-xs font-semibold uppercase tracking-wide text-ink-muted">
                            {item.type === "RESCUE"
                              ? "Rescue"
                              : item.sourceType === "WALK_IN"
                                ? "Walk-in"
                                : "Appointment"}
                          </p>
                        </div>
                      </div>
                    </td>
                    <td className={tdCell}>
                      <div className="flex flex-col">
                        <span className="font-semibold text-ink">
                          {customerName(item)}
                        </span>
                        <span className="inline-flex items-center gap-1 text-sm text-ink-muted">
                          <Phone size={13} />
                          {customerPhone(item) || "No phone"}
                        </span>
                      </div>
                    </td>
                    <td className={tdCell}>
                      <div className="flex flex-col">
                        <span className="inline-flex items-center gap-1 font-semibold text-ink">
                          <Bike size={14} />
                          {vehicleName(item) || "No vehicle"}
                        </span>
                        <span className="text-sm text-ink-muted">
                          {vehiclePlate(item) || "No plate"}
                        </span>
                      </div>
                    </td>
                    <td className={tdCell}>{formatDate(requestTime(item))}</td>
                    <td className={tdCell}>{statusBadge(item.status)}</td>
                    <td className={`${tdCell} text-right`}>
                      <button
                        className={iconBtnMaintenance}
                        onClick={() => setSelectedItem(item)}
                        title="View detail"
                        type="button"
                      >
                        <ReceiptText size={17} />
                      </button>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
        {!isLoading && filteredList.length > 0 && (
          <div className="flex flex-col gap-3 border-t border-edge px-5 py-4 sm:flex-row sm:items-center sm:justify-between">
            <p className="m-0 text-sm font-medium text-ink-muted">
              Showing {pageStart + 1}-
              {Math.min(pageStart + PAGE_SIZE, filteredList.length)} of{" "}
              {filteredList.length}
            </p>
            <div className="flex items-center gap-2">
              <button
                type="button"
                onClick={() => setPage((value) => Math.max(1, value - 1))}
                disabled={currentPage === 1}
                className="rounded-xl border border-edge bg-white px-4 py-2 text-sm font-semibold text-ink transition hover:border-primary hover:text-primary disabled:cursor-not-allowed disabled:opacity-45 disabled:hover:border-edge disabled:hover:text-ink"
              >
                Previous
              </button>
              <span className="min-w-20 text-center text-sm font-bold text-ink">
                {currentPage} / {totalPages}
              </span>
              <button
                type="button"
                onClick={() =>
                  setPage((value) => Math.min(totalPages, value + 1))
                }
                disabled={currentPage === totalPages}
                className="rounded-xl border border-edge bg-white px-4 py-2 text-sm font-semibold text-ink transition hover:border-primary hover:text-primary disabled:cursor-not-allowed disabled:opacity-45 disabled:hover:border-edge disabled:hover:text-ink"
              >
                Next
              </button>
            </div>
          </div>
        )}
      </div>

      {selectedItem && (
        <DetailModal
          item={selectedItem}
          onClose={() => setSelectedItem(null)}
        />
      )}
    </div>
  );
};

const SummaryCard = ({
  title,
  value,
  icon: Icon,
  tone = "orange",
}: {
  title: string;
  value: number;
  icon: LucideIcon;
  tone?: "orange" | "amber" | "green";
}) => {
  const toneClass =
    tone === "green"
      ? "bg-green-50 text-green-700"
      : tone === "amber"
        ? "bg-amber-50 text-amber-700"
        : "bg-primary-light text-primary";

  return (
    <div className="rounded-3xl border border-edge bg-white p-5 shadow-card">
      <div className="flex items-center justify-between gap-4">
        <div>
          <p className="m-0 text-sm font-semibold text-ink-muted">{title}</p>
          <p className="m-0 mt-1 font-display text-3xl font-black text-ink">
            {value}
          </p>
        </div>
        <div
          className={`flex h-12 w-12 items-center justify-center rounded-2xl ${toneClass}`}
        >
          <Icon size={22} />
        </div>
      </div>
    </div>
  );
};

const DetailModal = ({
  item,
  onClose,
}: {
  item: RequestRecord;
  onClose: () => void;
}) => {
  const rescueInvoice = parseInvoice(item.invoiceDetails);
  const [appointmentInvoice, setAppointmentInvoice] =
    useState<InvoiceData | null>(null);
  const [appointmentInvoiceLoading, setAppointmentInvoiceLoading] =
    useState(false);
  const embeddedAppointmentInvoice = useMemo(
    () => item.appointmentInvoice || parseInvoice(item.invoiceDetails),
    [item.appointmentInvoice, item.invoiceDetails],
  );

  useEffect(() => {
    const previousOverflow = document.body.style.overflow;
    document.body.style.overflow = "hidden";

    return () => {
      document.body.style.overflow = previousOverflow;
    };
  }, []);

  useEffect(() => {
    if (item.type !== "APPOINTMENT") {
      // eslint-disable-next-line react-hooks/set-state-in-effect
      setAppointmentInvoice(null);
      return;
    }

    if (embeddedAppointmentInvoice) {
      setAppointmentInvoice(embeddedAppointmentInvoice);
      setAppointmentInvoiceLoading(false);
      return;
    }

    if (item.status !== "COMPLETED") {
      setAppointmentInvoice(null);
      return;
    }

    const customerId = asNumber(item.customer?.id) || asNumber(item.customerId);
    if (!customerId) {
      setAppointmentInvoice(null);
      return;
    }

    let cancelled = false;
    setAppointmentInvoiceLoading(true);

    getMaintenanceByCustomer(customerId)
      .then((records) => {
        if (cancelled) return;
        setAppointmentInvoice(findAppointmentInvoice(item, records));
      })
      .catch((error) => {
        console.error("Failed to load appointment invoice", error);
        if (!cancelled) {
          setAppointmentInvoice(null);
          toast.error(
            `Failed to load appointment invoice: ${apiErrorLabel(error)}`,
          );
        }
      })
      .finally(() => {
        if (!cancelled) setAppointmentInvoiceLoading(false);
      });

    return () => {
      cancelled = true;
    };
  }, [embeddedAppointmentInvoice, item]);

  const displayItem = appointmentInvoice
    ? { ...item, appointmentInvoice }
    : item;

  return createPortal(
    <div
      className="fixed inset-0 z-[9999] flex min-h-screen w-screen items-center justify-center bg-stone-950/60 p-4 backdrop-blur-[3px]"
      onMouseDown={onClose}
    >
      <div
        className="flex max-h-[calc(100vh-2rem)] w-full max-w-4xl flex-col overflow-hidden rounded-[1.75rem] border border-edge bg-canvas shadow-float"
        onMouseDown={(event) => event.stopPropagation()}
      >
        <div className="flex items-start justify-between gap-5 border-b border-edge bg-white px-6 py-5">
          <div>
            <p className={eyebrow}>
              {item.type === "RESCUE" ? "Rescue detail" : "Appointment detail"}
            </p>
            <h2 className="m-0 mt-1 font-display text-2xl font-black text-ink">
              {item.sourceType === "WALK_IN" ? "Walk-in" : "Request"} #{item.id}
            </h2>
            <p className={pageSubtitle}>{formatDate(requestTime(item))}</p>
          </div>
          <button
            onClick={onClose}
            className="inline-flex h-10 w-10 shrink-0 items-center justify-center rounded-xl bg-primary-light text-ink-muted transition hover:bg-primary hover:text-white"
            type="button"
            aria-label="Close detail"
          >
            <X size={20} />
          </button>
        </div>

        <div id="print-section" className="overflow-y-auto px-6 py-5">
          <div className="mb-5 grid gap-3 md:grid-cols-2">
            <InfoCard
              icon={UserRound}
              label="Customer"
              title={customerName(displayItem)}
              detail={customerPhone(displayItem) || "No phone"}
            />
            <InfoCard
              icon={Bike}
              label="Vehicle"
              title={vehicleName(displayItem) || "No vehicle"}
              detail={vehiclePlate(displayItem) || "No plate"}
            />
          </div>

          <div className="mb-5 rounded-2xl border border-edge bg-white p-4 shadow-sm">
            {item.type === "RESCUE" ? (
              <div className="grid gap-3 text-sm text-ink md:grid-cols-2">
                <DetailLine
                  label="Staff Code"
                  value={item.staffCode || "Not updated"}
                />
                <DetailLine
                  label="Distance"
                  value={
                    item.distanceKm ? `${item.distanceKm.toFixed(2)} km` : "N/A"
                  }
                />
                <DetailLine
                  label="Issue"
                  value={item.issueDescription || "N/A"}
                  wide
                />
                <DetailLine
                  label="Status"
                  value={statusBadge(item.status)}
                  wide
                />
              </div>
            ) : (
              <div className="grid gap-3 text-sm text-ink md:grid-cols-2">
                <DetailLine
                  label="Appointment Time"
                  value={formatDate(item.appointmentDate)}
                />
                <DetailLine label="Status" value={statusBadge(item.status)} />
                <DetailLine label="Note" value={item.note || "None"} wide />
              </div>
            )}
          </div>

          {item.type === "RESCUE" && rescueInvoice ? (
            <InvoiceCard
              invoice={rescueInvoice}
              serviceLabel="Motorcycle Rescue Service"
            />
          ) : item.type === "RESCUE" ? (
            <LegacyInvoice item={item} />
          ) : appointmentInvoiceLoading ? (
            <div className="rounded-3xl border border-edge bg-white p-6 text-center text-ink-muted shadow-sm">
              <div className="mx-auto mb-3 h-8 w-8 animate-spin-fast rounded-full border-[3px] border-edge border-t-primary" />
              Loading invoice from maintenance history...
            </div>
          ) : displayItem.appointmentInvoice ? (
            <InvoiceCard
              invoice={displayItem.appointmentInvoice}
              serviceLabel="Maintenance Service"
            />
          ) : (
            <div className="rounded-3xl border border-edge bg-white p-6 text-center text-ink-muted shadow-sm">
              <CalendarDays size={34} className="mx-auto mb-3 text-primary" />
              This appointment is completed, but no maintenance invoice was
              found yet.
            </div>
          )}
        </div>

        <div className="flex justify-end gap-3 border-t border-edge bg-white px-6 py-4 no-print">
          <button
            className="rounded-xl border border-edge bg-primary px-5 py-2.5 text-sm font-semibold text-white transition hover:bg-primary-deep"
            onClick={() => window.print()}
            type="button"
          >
            <Printer size={16} className="inline-block mr-2" />
            Print Bill
          </button>
          <button
            className="rounded-xl border border-edge bg-white px-5 py-2.5 text-sm font-semibold text-ink transition hover:border-primary hover:text-primary"
            onClick={onClose}
            type="button"
          >
            Close
          </button>
        </div>
      </div>
    </div>,
    document.body,
  );
};

const InfoCard = ({
  icon: Icon,
  label,
  title,
  detail,
}: {
  icon: LucideIcon;
  label: string;
  title: string;
  detail: string;
}) => (
  <div className="rounded-2xl border border-edge bg-white p-4 shadow-sm">
    <div className="flex items-start gap-3">
      <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-primary-light text-primary">
        <Icon size={18} />
      </div>
      <div>
        <p className="m-0 text-xs font-bold uppercase tracking-[2px] text-ink-muted">
          {label}
        </p>
        <p className="m-0 mt-1 font-semibold text-ink">{title}</p>
        <p className="m-0 text-sm text-ink-muted">{detail}</p>
      </div>
    </div>
  </div>
);

const DetailLine = ({
  label,
  value,
  wide = false,
}: {
  label: string;
  value: ReactNode;
  wide?: boolean;
}) => (
  <div className={wide ? "md:col-span-2" : undefined}>
    <span className="mr-2 font-semibold text-ink-muted">{label}:</span>
    <span className="font-semibold">{value}</span>
  </div>
);

const InvoiceCard = ({
  invoice,
  serviceLabel,
}: {
  invoice: InvoiceData;
  serviceLabel: string;
}) => (
  <div className="rounded-3xl border border-edge bg-white p-5 shadow-card">
    <div className="mb-5 rounded-2xl bg-primary-light/60 px-4 py-5 text-center">
      <CareBikeWordmark />
      <p className="m-0 mt-1 text-xs font-semibold uppercase tracking-wide text-ink-muted">
        {serviceLabel}
      </p>
      <p className="m-0 mt-1 text-xs text-ink-muted">Date: {invoice.date}</p>
    </div>

    <InvoiceSection title="Customer Information">
      <InvoiceGrid
        rows={[
          ["Name", invoice.customerName],
          ["Phone", invoice.customerPhone],
          ["Vehicle", invoice.vehicleName],
          ["Plate", invoice.vehiclePlate],
        ]}
      />
    </InvoiceSection>

    <InvoiceSection title="Staff Information">
      <InvoiceGrid
        rows={[
          ["Staff Code", invoice.staffCode],
          ["Name", invoice.staffName],
        ]}
      />
    </InvoiceSection>

    <div className="rounded-2xl border border-edge p-4">
      <p className="mb-3 mt-0 text-xs font-black uppercase tracking-[2px] text-ink-muted">
        Services Used
      </p>
      {asNumber(invoice.laborCost) > 0 && (
        <InvoiceRow
          label="Rescue labor fee"
          amount={asNumber(invoice.laborCost)}
        />
      )}
      {invoice.items?.map((line, index) => (
        <InvoiceRow
          key={`${line.name}-${index}`}
          label={`${line.name || "Service"} x${asNumber(line.quantity) || 1}`}
          amount={asNumber(line.price) * (asNumber(line.quantity) || 1)}
        />
      ))}
      {asNumber(invoice.transportFee) > 0 && (
        <InvoiceRow
          label={`Staff travel (${Number(invoice.distanceKm || 0).toFixed(1)}km - Round trip)`}
          amount={asNumber(invoice.transportFee)}
        />
      )}
    </div>

    <div className="mt-4 flex items-center justify-between rounded-2xl bg-ink px-4 py-3 text-white">
      <span className="font-display text-xl font-black text-white">TOTAL</span>
      <span className="font-display text-xl font-black text-primary-bright">
        {formatCurrency(invoice.totalAmount)}
      </span>
    </div>
  </div>
);

const InvoiceSection = ({
  title,
  children,
}: {
  title: string;
  children: ReactNode;
}) => (
  <div className="mb-4 rounded-2xl border border-edge p-4">
    <p className="mb-3 mt-0 text-xs font-black uppercase tracking-[2px] text-ink-muted">
      {title}
    </p>
    {children}
  </div>
);

const InvoiceGrid = ({
  rows,
}: {
  rows: Array<[string, string | undefined]>;
}) => (
  <div className="grid grid-cols-[6rem_1fr] gap-x-4 gap-y-2 text-sm">
    {rows.map(([label, value]) => (
      <Fragment key={label}>
        <span className="text-ink-muted">{label}</span>
        <strong className="text-ink">{value || "N/A"}</strong>
      </Fragment>
    ))}
  </div>
);

const InvoiceRow = ({ label, amount }: { label: string; amount: number }) => (
  <div className="mb-2 flex justify-between gap-5 text-sm text-ink">
    <span>{label}</span>
    <strong>{formatCurrency(amount)}</strong>
  </div>
);

const LegacyInvoice = ({ item }: { item: RequestRecord }) => (
  <div className="rounded-3xl border border-edge bg-white p-5 shadow-sm">
    <h3 className="m-0 mb-3 flex items-center gap-2 font-display text-lg font-black text-ink">
      <FileText size={20} className="text-primary" />
      Invoice Details
    </h3>
    {item.invoiceDetails ? (
      <div className="rounded-2xl bg-primary-light p-4 text-sm leading-6 text-ink">
        {item.invoiceDetails}
      </div>
    ) : (
      <InvoiceRow label="Transport Fee" amount={item.transportFee || 0} />
    )}
    <div className="mt-4 flex justify-between border-t-2 border-dashed border-edge pt-4 text-lg">
      <strong className="text-ink">TOTAL INVOICE</strong>
      <strong className="text-primary">
        {formatCurrency(item.totalCost || item.transportFee || 0)}
      </strong>
    </div>
  </div>
);

const CareBikeWordmark = () => (
  <div className="font-display text-3xl font-black italic leading-none tracking-tight">
    <span className="text-primary">CARE</span>
    <span className="text-ink">BIKE</span>
  </div>
);

const asText = (value: unknown) =>
  typeof value === "string" || typeof value === "number" ? String(value) : "";

const asNumber = (value: unknown) =>
  typeof value === "number"
    ? value
    : typeof value === "string"
      ? Number(value) || 0
      : 0;

const apiErrorLabel = (error: unknown) => {
  const details = error as {
    message?: string;
    response?: {
      status?: number;
      data?: {
        error?: string;
        message?: string;
      };
    };
  };
  const status = details.response?.status;
  const message =
    details.response?.data?.message ||
    details.response?.data?.error ||
    details.message;

  return [status, message].filter(Boolean).join(" - ") || "unknown error";
};

const customerName = (item: RequestRecord) =>
  asText(item.customer?.fullName) || asText(item.customerName) || "Anonymous";

const customerPhone = (item: RequestRecord) =>
  asText(item.appointmentInvoice?.customerPhone) ||
  asText(item.customer?.phone) ||
  asText(item.customerPhone);

const vehicleName = (item: RequestRecord) => {
  const invoiceVehicleName = asText(item.appointmentInvoice?.vehicleName);
  if (invoiceVehicleName) return invoiceVehicleName;

  const directVehicleName = asText(item.vehicleName);
  if (directVehicleName) return directVehicleName;

  const vehicle = item.vehicle;
  return [
    asText(vehicle?.brand),
    asText(vehicle?.vehicleName) || asText(vehicle?.model),
  ]
    .filter(Boolean)
    .join(" ");
};

const vehiclePlate = (item: RequestRecord) =>
  asText(item.appointmentInvoice?.vehiclePlate) ||
  asText(item.vehiclePlate) ||
  asText(item.vehicle?.licensePlate);

const requestTime = (item: RequestRecord) =>
  item.type === "RESCUE"
    ? asText(item.createdAt)
    : asText(item.appointmentDate);

const sortByRequestTimeDesc = (a: RequestRecord, b: RequestRecord) => {
  const aTime = Date.parse(requestTime(a));
  const bTime = Date.parse(requestTime(b));
  const timeCompare =
    (Number.isNaN(bTime) ? 0 : bTime) - (Number.isNaN(aTime) ? 0 : aTime);

  return timeCompare || b.id - a.id;
};

const formatDate = (value?: string) => {
  if (!value) return "N/A";
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? "N/A" : date.toLocaleString("vi-VN");
};

const formatCurrency = (amount = 0) =>
  `${Math.round(Number(amount || 0)).toLocaleString("vi-VN")} VNĐ`;

const parseInvoice = (value?: string) => {
  if (!value?.trim()?.startsWith("{")) return null;
  try {
    return JSON.parse(value.trim()) as InvoiceData;
  } catch (error) {
    console.error("Failed to parse invoice JSON", error);
    return null;
  }
};

const enrichAppointmentsWithInvoices = async (
  appointments: RequestRecord[],
) => {
  const appointmentsByCustomer = new Map<number, RequestRecord[]>();

  appointments.forEach((appointment) => {
    if (appointment.status !== "COMPLETED") return;
    const customerId =
      asNumber(appointment.customer?.id) || asNumber(appointment.customerId);
    if (!customerId) return;

    const list = appointmentsByCustomer.get(customerId) || [];
    list.push(appointment);
    appointmentsByCustomer.set(customerId, list);
  });

  if (appointmentsByCustomer.size === 0) return appointments;

  const invoiceByAppointmentId = new Map<number, InvoiceData>();
  const results = await Promise.allSettled(
    Array.from(appointmentsByCustomer.entries()).map(
      async ([customerId, customerAppointments]) => {
        const records = await getMaintenanceByCustomer(customerId);
        customerAppointments.forEach((appointment) => {
          const invoice = findAppointmentInvoice(appointment, records);
          if (invoice) invoiceByAppointmentId.set(appointment.id, invoice);
        });
      },
    ),
  );

  results.forEach((result) => {
    if (result.status === "rejected") {
      console.error("Failed to enrich appointment invoice data", result.reason);
    }
  });

  return appointments.map((appointment) => {
    const invoice = invoiceByAppointmentId.get(appointment.id);
    if (!invoice) return appointment;

    return {
      ...appointment,
      appointmentInvoice: invoice,
      customerPhone: customerPhone(appointment) || invoice.customerPhone,
    };
  });
};

const findAppointmentInvoice = (
  appointment: RequestRecord,
  records: MaintenanceHistoryRecord[],
) => {
  const appointmentId = asNumber(appointment.id);
  const branchId =
    asNumber(appointment.branch?.id) || asNumber(appointment.branchId);

  const candidates = records
    .map((record) => ({
      record,
      invoice: parseInvoice(record.serviceDetails || undefined),
    }))
    .filter(
      (entry) =>
        entry.invoice?.sourceType === "APPOINTMENT" ||
        entry.invoice?.appointmentId,
    );

  const exactMatch = candidates.find(
    ({ invoice }) => asNumber(invoice?.appointmentId) === appointmentId,
  );
  if (exactMatch?.invoice) return exactMatch.invoice;

  const branchMatchedAppointmentInvoices = candidates.filter(
    ({ record, invoice }) => {
      if (!invoice) return false;
      if (asNumber(invoice.appointmentId) > 0) return false;

      const recordBranchId =
        asNumber(record.branch?.id) || asNumber(record.branchId);
      return !branchId || !recordBranchId || branchId === recordBranchId;
    },
  );
  if (branchMatchedAppointmentInvoices.length === 1) {
    return branchMatchedAppointmentInvoices[0].invoice;
  }

  const legacyMaintenanceCandidates = records
    .map((record) => ({
      record,
      invoice: parseInvoice(record.serviceDetails || undefined),
    }))
    .filter(({ record, invoice }) => {
      if (!invoice) return false;
      if (invoice.sourceType || invoice.appointmentId) return false;

      const recordBranchId =
        asNumber(record.branch?.id) || asNumber(record.branchId);
      const branchMatches =
        !branchId || !recordBranchId || branchId === recordBranchId;
      const looksLikeMaintenance =
        asNumber(invoice.distanceKm) === 0 &&
        asNumber(invoice.transportFee) === 0;

      return branchMatches && looksLikeMaintenance;
    });

  return legacyMaintenanceCandidates.length === 1
    ? legacyMaintenanceCandidates[0].invoice
    : null;
};

const statusBadge = (status: string) => {
  const config: Record<
    string,
    { label: string; className: string; icon: LucideIcon }
  > = {
    PENDING: {
      label: "Pending",
      className: "bg-amber-50 text-amber-700",
      icon: Clock,
    },
    ACCEPTED: {
      label: "Processing",
      className: "bg-blue-50 text-blue-600",
      icon: Wrench,
    },
    CONFIRMED: {
      label: "Processing",
      className: "bg-blue-50 text-blue-600",
      icon: Wrench,
    },
    COMPLETED: {
      label: "Completed",
      className: "bg-green-50 text-green-700",
      icon: CheckCircle,
    },
    CANCELLED: {
      label: "Cancelled",
      className: "bg-red-50 text-red-600",
      icon: XCircle,
    },
  };
  const item = config[status] ?? {
    label: status,
    className: "bg-stone-100 text-ink-muted",
    icon: Clock,
  };
  const Icon = item.icon;

  return (
    <span
      className={`inline-flex items-center gap-1.5 rounded-full px-2.5 py-1 text-xs font-bold ${item.className}`}
    >
      <Icon size={13} />
      {item.label}
    </span>
  );
};

export default BranchRequestHistory;
