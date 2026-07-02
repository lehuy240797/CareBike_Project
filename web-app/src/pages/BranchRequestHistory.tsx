import { useState, useEffect, useCallback, useMemo } from 'react';
import { History, Search, FileText, CheckCircle, Clock, XCircle, Wrench, X } from 'lucide-react';
import apiClient from '../services/apiClient';
import { useAuth } from '../context/AuthContext';
import toast from 'react-hot-toast';

interface RequestRecord {
    id: number;
    type: 'RESCUE' | 'APPOINTMENT';
    status: string;
    customer: any;
    vehicle: any;
    createdAt?: string;
    appointmentDate?: string;
    [key: string]: any;
}

const BranchRequestHistory = () => {
    const { user } = useAuth();
    const branchId = (user as any)?.branchId;

    const [activeTab, setActiveTab] = useState<'RESCUE' | 'APPOINTMENT'>('RESCUE');
    const [rescues, setRescues] = useState<RequestRecord[]>([]);
    const [appointments, setAppointments] = useState<RequestRecord[]>([]);
    const [isLoading, setIsLoading] = useState(true);
    const [searchTerm, setSearchTerm] = useState('');
    const [selectedItem, setSelectedItem] = useState<RequestRecord | null>(null);

    const fetchData = useCallback(async () => {
        if (!branchId) return;
        setIsLoading(true);
        try {
            const [resRescues, resAppointments] = await Promise.all([
                apiClient.get(`/rescues/branch/${branchId}`),
                apiClient.get(`/appointments/branch/${branchId}`)
            ]);

            const mappedRescues = resRescues.data.map((r: any) => ({ ...r, type: 'RESCUE' }));
            const mappedAppointments = resAppointments.data.map((a: any) => ({ ...a, type: 'APPOINTMENT' }));

            // Sắp xếp mới nhất lên đầu
            mappedRescues.sort((a: any, b: any) => b.id - a.id);
            mappedAppointments.sort((a: any, b: any) => b.id - a.id);

            setRescues(mappedRescues);
            setAppointments(mappedAppointments);
        } catch (error) {
            console.error(error);
            toast.error("Failed to load request history.");
        } finally {
            setIsLoading(false);
        }
    }, [branchId]);

    useEffect(() => {
        fetchData();
    }, [fetchData]);

    const activeList = activeTab === 'RESCUE' ? rescues : appointments;

    const filteredList = useMemo(() => {
        if (!searchTerm) return activeList;
        const lowerTerm = searchTerm.toLowerCase();
        return activeList.filter(item => 
            item.id.toString().includes(lowerTerm) ||
            item.customer?.fullName?.toLowerCase().includes(lowerTerm) ||
            item.customer?.phone?.includes(lowerTerm) ||
            item.vehicle?.licensePlate?.toLowerCase().includes(lowerTerm)
        );
    }, [activeList, searchTerm]);

    const formatCurrency = (amount: number) => {
        return Math.round(amount).toLocaleString('vi-VN') + ' VNĐ';
    };

    const getStatusBadge = (status: string) => {
        switch (status) {
            case 'PENDING': return <span style={{ color: 'orange', fontWeight: 'bold' }}><Clock size={14} style={{ display: 'inline', marginRight: 4 }}/>Pending</span>;
            case 'ACCEPTED': 
            case 'CONFIRMED': return <span style={{ color: 'blue', fontWeight: 'bold' }}><Wrench size={14} style={{ display: 'inline', marginRight: 4 }}/>Processing</span>;
            case 'COMPLETED': return <span style={{ color: 'green', fontWeight: 'bold' }}><CheckCircle size={14} style={{ display: 'inline', marginRight: 4 }}/>Completed</span>;
            case 'CANCELLED': return <span style={{ color: 'red', fontWeight: 'bold' }}><XCircle size={14} style={{ display: 'inline', marginRight: 4 }}/>Cancelled</span>;
            default: return <span>{status}</span>;
        }
    };

    return (
        <div className="dashboard-inner" style={{ position: 'relative' }}>
            <div className="page-header" style={{ marginBottom: '1.75rem' }}>
                <History size={28} className="page-header-icon" aria-hidden="true" />
                <div style={{ flex: 1 }}>
                    <h1 className="dashboard-title" style={{ margin: 0 }}>Request & Invoice History</h1>
                    <p className="page-subtitle">View all Rescues and Appointments</p>
                </div>
            </div>

            {/* Tabs & Search */}
            <div style={{ display: 'flex', gap: '1rem', marginBottom: '1rem', flexWrap: 'wrap', alignItems: 'center' }}>
                <div style={{ display: 'flex', background: 'var(--color-surface)', borderRadius: '8px', overflow: 'hidden', border: '1px solid var(--color-border)' }}>
                    <button 
                        onClick={() => setActiveTab('RESCUE')}
                        style={{ padding: '10px 20px', background: activeTab === 'RESCUE' ? 'var(--color-primary)' : 'transparent', color: activeTab === 'RESCUE' ? 'white' : 'inherit', border: 'none', cursor: 'pointer', fontWeight: 'bold' }}
                    >
                        RESCUES
                    </button>
                    <button 
                        onClick={() => setActiveTab('APPOINTMENT')}
                        style={{ padding: '10px 20px', background: activeTab === 'APPOINTMENT' ? 'var(--color-primary)' : 'transparent', color: activeTab === 'APPOINTMENT' ? 'white' : 'inherit', border: 'none', cursor: 'pointer', fontWeight: 'bold' }}
                    >
                        APPOINTMENTS
                    </button>
                </div>
                
                <div style={{ flex: 1, minWidth: '250px', position: 'relative' }}>
                    <Search size={18} style={{ position: 'absolute', left: 12, top: 11, color: 'var(--color-text-muted)' }} />
                    <input 
                        type="text" 
                        placeholder="Search by ID, Name, Phone, License Plate..." 
                        value={searchTerm}
                        onChange={(e) => setSearchTerm(e.target.value)}
                        style={{ width: '100%', padding: '10px 10px 10px 38px', borderRadius: '8px', border: '1px solid var(--color-border)', backgroundColor: 'var(--color-surface)', color: 'var(--color-text)' }}
                    />
                </div>
            </div>

            {/* Table */}
            <div className="table-card">
                <div className="table-scroll">
                    <table className="data-table">
                        <thead>
                            <tr>
                                <th>ID</th>
                                <th>Customer</th>
                                <th>Vehicle Info</th>
                                <th>Time</th>
                                <th>Status</th>
                                <th>Actions</th>
                            </tr>
                        </thead>
                        <tbody>
                            {isLoading ? (
                                <tr><td colSpan={6} style={{ textAlign: 'center', padding: '2rem' }}>Loading data...</td></tr>
                            ) : filteredList.length === 0 ? (
                                <tr><td colSpan={6} style={{ textAlign: 'center', padding: '2rem', color: 'var(--color-text-muted)' }}>No data found.</td></tr>
                            ) : filteredList.map(item => (
                                <tr key={item.id}>
                                    <td className="font-medium">#{item.id}</td>
                                    <td>
                                        <div className="font-medium">{item.customer?.fullName ?? 'Anonymous'}</div>
                                        <div style={{ fontSize: '0.85rem', color: 'var(--color-text-muted)' }}>{item.customer?.phone}</div>
                                    </td>
                                    <td>
                                        <div>{item.vehicle?.brand} {item.vehicle?.model}</div>
                                        <div style={{ fontSize: '0.85rem', color: 'var(--color-text-muted)' }}>{item.vehicle?.licensePlate}</div>
                                    </td>
                                    <td>
                                        {activeTab === 'RESCUE' ? new Date(item.createdAt || '').toLocaleString('vi-VN') : new Date(item.appointmentDate || '').toLocaleString('vi-VN')}
                                    </td>
                                    <td>{getStatusBadge(item.status)}</td>
                                    <td>
                                        <button className="app-btn-icon" onClick={() => setSelectedItem(item)} title="View Invoice Detail">
                                            <FileText size={18} />
                                        </button>
                                    </td>
                                </tr>
                            ))}
                        </tbody>
                    </table>
                </div>
            </div>

            {/* Detail Modal */}
            {selectedItem && (
                <div style={{
                    position: 'fixed', top: 0, left: 0, right: 0, bottom: 0,
                    backgroundColor: 'rgba(0,0,0,0.5)', zIndex: 1000,
                    display: 'flex', alignItems: 'center', justifyContent: 'center', padding: '20px'
                }}>
                    <div style={{
                        backgroundColor: 'var(--color-surface)', width: '100%', maxWidth: '600px',
                        borderRadius: '16px', padding: '24px', maxHeight: '90vh', overflowY: 'auto',
                        boxShadow: '0 10px 25px rgba(0,0,0,0.2)', position: 'relative'
                    }}>
                        <button onClick={() => setSelectedItem(null)} style={{ position: 'absolute', right: 20, top: 20, background: 'none', border: 'none', cursor: 'pointer', color: 'var(--color-text-muted)' }}>
                            <X size={24} />
                        </button>
                        
                        <h2 style={{ margin: '0 0 20px 0', borderBottom: '2px solid var(--color-border)', paddingBottom: '12px', display: 'flex', alignItems: 'center', gap: '8px' }}>
                            <FileText size={24} color="var(--color-primary)" />
                            {selectedItem.type === 'RESCUE' ? 'RESCUE' : 'APPOINTMENT'} DETAIL #{selectedItem.id}
                        </h2>

                        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '16px', marginBottom: '24px' }}>
                            <div>
                                <p style={{ color: 'var(--color-text-muted)', margin: '0 0 4px 0', fontSize: '0.85rem' }}>Customer</p>
                                <p style={{ margin: 0, fontWeight: 'bold' }}>{selectedItem.customer?.fullName}</p>
                                <p style={{ margin: 0 }}>{selectedItem.customer?.phone}</p>
                            </div>
                            <div>
                                <p style={{ color: 'var(--color-text-muted)', margin: '0 0 4px 0', fontSize: '0.85rem' }}>Vehicle</p>
                                <p style={{ margin: 0, fontWeight: 'bold' }}>{selectedItem.vehicle?.brand} {selectedItem.vehicle?.model}</p>
                                <p style={{ margin: 0 }}>License Plate: {selectedItem.vehicle?.licensePlate}</p>
                            </div>
                        </div>

                        {selectedItem.type === 'RESCUE' && (
                            <div style={{ background: 'var(--color-background)', padding: '16px', borderRadius: '8px', marginBottom: '24px' }}>
                                <p style={{ margin: '0 0 8px 0' }}><strong>Staff Code:</strong> {selectedItem.staffCode ?? 'Not updated'}</p>
                                <p style={{ margin: '0 0 8px 0', color: 'var(--color-error)' }}><strong>Issue:</strong> {selectedItem.issueDescription}</p>
                                <p style={{ margin: '0 0 8px 0' }}><strong>Distance:</strong> {selectedItem.distanceKm ? `${selectedItem.distanceKm.toFixed(2)} km` : 'N/A'}</p>
                                <p style={{ margin: 0 }}><strong>Status:</strong> {getStatusBadge(selectedItem.status)}</p>
                            </div>
                        )}

                        {selectedItem.type === 'APPOINTMENT' && (
                            <div style={{ background: 'var(--color-background)', padding: '16px', borderRadius: '8px', marginBottom: '24px' }}>
                                <p style={{ margin: '0 0 8px 0' }}><strong>Appointment Time:</strong> {new Date(selectedItem.appointmentDate || '').toLocaleString('vi-VN')}</p>
                                <p style={{ margin: '0 0 8px 0' }}><strong>Note:</strong> {selectedItem.note || 'None'}</p>
                                <p style={{ margin: 0 }}><strong>Status:</strong> {getStatusBadge(selectedItem.status)}</p>
                            </div>
                        )}

                        {/* Hóa đơn chi tiết */}
                        {selectedItem.type === 'RESCUE' && (selectedItem.status === 'COMPLETED' || selectedItem.transportFee != null) && (() => {
                            let invoiceData: any = null;
                            if (selectedItem.invoiceDetails && selectedItem.invoiceDetails.startsWith('{')) {
                                try {
                                    invoiceData = JSON.parse(selectedItem.invoiceDetails);
                                } catch (e) {
                                    console.error("Failed to parse invoice JSON", e);
                                }
                            }

                            if (invoiceData) {
                                return (
                                    <div style={{ background: '#fff', border: '1px solid #e0e0e0', borderRadius: '16px', padding: '24px', marginTop: '24px', boxShadow: '0 4px 12px rgba(0,0,0,0.05)' }}>
                                        <div style={{ textAlign: 'center', marginBottom: '24px' }}>
                                            <h2 style={{ margin: 0, color: 'var(--color-primary)', letterSpacing: '2px', fontSize: '1.5rem', fontWeight: 900 }}>CAREBIKE</h2>
                                            <p style={{ margin: '4px 0 0 0', fontSize: '0.8rem', color: 'var(--color-text-muted)', textTransform: 'uppercase' }}>Motorcycle Rescue Service</p>
                                            <p style={{ margin: '4px 0 0 0', fontSize: '0.75rem', color: 'var(--color-text-muted)' }}>Date: {invoiceData.date}</p>
                                        </div>
                                        
                                        <div style={{ borderBottom: '1px solid #e0e0e0', paddingBottom: '16px', marginBottom: '16px' }}>
                                            <p style={{ fontSize: '0.75rem', fontWeight: 800, color: 'var(--color-text-muted)', marginBottom: '12px' }}>CUSTOMER INFORMATION</p>
                                            <div style={{ display: 'grid', gridTemplateColumns: '100px 1fr', gap: '8px', fontSize: '0.9rem' }}>
                                                <span style={{ color: 'var(--color-text-muted)' }}>Name</span><strong style={{ color: 'var(--color-text)' }}>{invoiceData.customerName}</strong>
                                                <span style={{ color: 'var(--color-text-muted)' }}>Phone</span><strong style={{ color: 'var(--color-text)' }}>{invoiceData.customerPhone}</strong>
                                                <span style={{ color: 'var(--color-text-muted)' }}>Vehicle</span><strong style={{ color: 'var(--color-text)' }}>{invoiceData.vehicleName}</strong>
                                                <span style={{ color: 'var(--color-text-muted)' }}>Plate</span><strong style={{ color: 'var(--color-text)' }}>{invoiceData.vehiclePlate}</strong>
                                            </div>
                                        </div>
                                        
                                        <div style={{ borderBottom: '1px solid #e0e0e0', paddingBottom: '16px', marginBottom: '16px' }}>
                                            <p style={{ fontSize: '0.75rem', fontWeight: 800, color: 'var(--color-text-muted)', marginBottom: '12px' }}>STAFF INFORMATION</p>
                                            <div style={{ display: 'grid', gridTemplateColumns: '100px 1fr', gap: '8px', fontSize: '0.9rem' }}>
                                                <span style={{ color: 'var(--color-text-muted)' }}>Staff Code</span><strong style={{ color: 'var(--color-text)' }}>{invoiceData.staffCode}</strong>
                                                <span style={{ color: 'var(--color-text-muted)' }}>Name</span><strong style={{ color: 'var(--color-text)' }}>{invoiceData.staffName}</strong>
                                            </div>
                                        </div>
                                        
                                        <div style={{ borderBottom: '2px solid #333', paddingBottom: '16px', marginBottom: '16px' }}>
                                            <p style={{ fontSize: '0.75rem', fontWeight: 800, color: 'var(--color-text-muted)', marginBottom: '12px' }}>SERVICES USED</p>
                                            
                                            {invoiceData.laborCost > 0 && (
                                                <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '8px', fontSize: '0.9rem' }}>
                                                    <span>Rescue labor fee</span>
                                                    <strong>{formatCurrency(invoiceData.laborCost)}</strong>
                                                </div>
                                            )}
                                            
                                            {invoiceData.items?.map((item: any, idx: number) => (
                                                <div key={idx} style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '8px', fontSize: '0.9rem' }}>
                                                    <span>{item.name} x{item.quantity}</span>
                                                    <strong>{formatCurrency(item.price * item.quantity)}</strong>
                                                </div>
                                            ))}
                                            
                                            {invoiceData.transportFee > 0 && (
                                                <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '8px', fontSize: '0.9rem' }}>
                                                    <span>Staff travel ({invoiceData.distanceKm?.toFixed(1)}km - Round trip)</span>
                                                    <strong>{formatCurrency(invoiceData.transportFee)}</strong>
                                                </div>
                                            )}
                                        </div>
                                        
                                        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                                            <span style={{ fontSize: '1.25rem', fontWeight: 900 }}>TOTAL</span>
                                            <span style={{ fontSize: '1.25rem', fontWeight: 900, color: 'var(--color-primary)' }}>{formatCurrency(invoiceData.totalAmount)}</span>
                                        </div>
                                    </div>
                                );
                            }

                            // Fallback for old records (plain text)
                            return (
                                <div style={{ marginTop: '24px' }}>
                                    <h3 style={{ borderBottom: '1px solid var(--color-border)', paddingBottom: '8px', marginBottom: '12px', display: 'flex', alignItems: 'center', gap: '8px' }}>
                                        <FileText size={20} color="var(--color-primary)" />
                                        Invoice Details
                                    </h3>
                                    
                                    {selectedItem.invoiceDetails ? (
                                        <div style={{ background: 'var(--color-background)', padding: '16px', borderRadius: '8px', fontSize: '0.95rem', whiteSpace: 'pre-wrap', lineHeight: '1.6' }}>
                                            {selectedItem.invoiceDetails}
                                        </div>
                                    ) : (
                                        <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '8px' }}>
                                            <span>Transport Fee:</span>
                                            <strong>{formatCurrency(selectedItem.transportFee || 0)}</strong>
                                        </div>
                                    )}
                                    
                                    <div style={{ display: 'flex', justifyContent: 'space-between', marginTop: '16px', paddingTop: '16px', borderTop: '2px dashed var(--color-border)', fontSize: '1.2rem' }}>
                                        <strong>TOTAL INVOICE:</strong>
                                        <strong style={{ color: 'var(--color-primary)' }}>{formatCurrency(selectedItem.totalCost || selectedItem.transportFee || 0)}</strong>
                                    </div>
                                    <p style={{ textAlign: 'right', fontSize: '0.85rem', color: 'var(--color-text-muted)', marginTop: '8px' }}>
                                        *Total amount paid by the customer
                                    </p>
                                </div>
                            );
                        })()}

                        <div style={{ display: 'flex', justifyContent: 'flex-end', marginTop: '24px' }}>
                            <button className="app-btn app-btn-secondary" onClick={() => setSelectedItem(null)}>Close</button>
                        </div>
                    </div>
                </div>
            )}
        </div>
    );
};

export default BranchRequestHistory;
