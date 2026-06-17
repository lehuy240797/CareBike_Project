import React, { useState, useEffect, useRef, useMemo, useCallback } from 'react';
import { X, MapPin, Search, Save, AlertCircle, UserCircle } from 'lucide-react';
import { MapContainer, TileLayer, Marker, useMap } from 'react-leaflet';
import L from 'leaflet';
import { createBranch, updateBranch } from '../../services/branchService';
import { apiGetAvailableManagers } from '../../services/userService';
import provinceDataRaw from '../../data/province.json';
import wardDataRaw from '../../data/ward.json';
import markerIcon2x from 'leaflet/dist/images/marker-icon-2x.png';
import markerIcon from 'leaflet/dist/images/marker-icon.png';
import markerShadow from 'leaflet/dist/images/marker-shadow.png';

delete (L.Icon.Default.prototype as any)._getIconUrl;
L.Icon.Default.mergeOptions({
  iconUrl: markerIcon,
  iconRetinaUrl: markerIcon2x,
  shadowUrl: markerShadow,
});

const PROVINCE_LIST = Object.values(provinceDataRaw) as any[];
const WARD_LIST = Object.values(wardDataRaw) as any[];

const MapUpdater = ({ center }: { center: [number, number] }) => {
  const map = useMap();
  useEffect(() => { map.flyTo(center, 16); }, [center, map]);
  return null;
};

interface BranchModalProps {
  mode: 'create' | 'edit';
  branch: any | null;
  onClose: () => void;
  onSuccess: (savedData: any) => void;
}

const BranchModal: React.FC<BranchModalProps> = ({ mode, branch, onClose, onSuccess }) => {
  // ── 1. STATE THÔNG TIN CƠ BẢN
  const [name, setName] = useState(branch?.name || '');
  const [phone, setPhone] = useState(branch?.phone || '');
  const [status, setStatus] = useState(branch?.status || 'ACTIVE');

  // ── 2. STATE LOGIC QUẢN LÝ (Từ code cũ)
  const [selectedManagerId, setSelectedManagerId] = useState<string>(branch?.manager?.id != null ? String(branch.manager.id) : '');
  const [availableManagers, setAvailableManagers] = useState<any[]>([]);
  const [managersLoading, setManagersLoading] = useState(false);
  const [managersError, setManagersError] = useState('');

  // ── 3. STATE ĐỊA CHỈ & BẢN ĐỒ (Từ thiết kế mới)
  const [provinces, setProvinces] = useState<any[]>([]);
  const [wards, setWards] = useState<any[]>([]);
  const [selectedProvince, setSelectedProvince] = useState<any>(null);
  const [selectedWard, setSelectedWard] = useState<any>(null);
  const [street, setStreet] = useState('');

  const [lat, setLat] = useState<number>(branch?.latitude || 10.776111);
  const [lng, setLng] = useState<number>(branch?.longitude || 106.695833);
  const [isSearchingMap, setIsSearchingMap] = useState(false);
  const markerRef = useRef<L.Marker>(null);

  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState('');

  // ── EFFECT TẢI ĐỊA CHỈ TỈNH
  useEffect(() => {
    const sortedProvinces = [...PROVINCE_LIST].sort((a, b) => a.name.localeCompare(b.name));
    setProvinces(sortedProvinces);

    if (mode === 'edit' && branch?.address) {
      setStreet(branch.address);
    }
  }, [mode, branch]);

  // ── EFFECT TẢI QUẢN LÝ (Logic cũ giữ nguyên)
  const loadAvailableManagers = useCallback(async () => {
    setManagersLoading(true);
    setManagersError('');
    try {
      const currentBranchId = mode === 'edit' ? branch?.id : undefined;
      const list = await apiGetAvailableManagers(currentBranchId);
      setAvailableManagers(Array.isArray(list) ? list : []);
    } catch {
      setManagersError('Không thể tải danh sách quản lý.');
    } finally {
      setManagersLoading(false);
    }
  }, [mode, branch]);

  useEffect(() => { loadAvailableManagers(); }, [loadAvailableManagers]);

  // ── HÀM XỬ LÝ ĐỊA CHỈ & BẢN ĐỒ
  const handleProvinceChange = (e: React.ChangeEvent<HTMLSelectElement>) => {
    const code = e.target.value;
    const p = provinces.find((x) => x.code.toString() === code);

    setSelectedProvince(p);
    setSelectedWard(null);

    if (code) {
      const filteredWards = WARD_LIST.filter(w => w.parent_code.toString() === code);
      filteredWards.sort((a, b) => a.name.localeCompare(b.name));
      setWards(filteredWards);
    } else {
      setWards([]);
    }
  };

  const handleWardChange = (e: React.ChangeEvent<HTMLSelectElement>) => {
    const code = e.target.value;
    const w = wards.find((x) => x.code.toString() === code);
    setSelectedWard(w);
  };

  const searchLocation = async () => {
    setError('');
    let fullAddress = street.trim();

    if (selectedWard && selectedProvince) {
      fullAddress = `${street.trim()}, ${selectedWard.name_with_type}, ${selectedProvince.name_with_type}`;
    }

    if (!fullAddress) {
      setError('Vui lòng nhập địa chỉ để tìm kiếm.');
      return;
    }

    setIsSearchingMap(true);
    try {
      const response = await fetch(`https://nominatim.openstreetmap.org/search?format=json&q=${encodeURIComponent(fullAddress + ', Vietnam')}&limit=1`);
      const data = await response.json();

      if (data && data.length > 0) {
        setLat(parseFloat(data[0].lat));
        setLng(parseFloat(data[0].lon));
      } else {
        setError('Không tìm thấy địa điểm. Vui lòng tự kéo thả kim đỏ.');
      }
    } catch (err) {
      setError('Lỗi kết nối bản đồ.');
    } finally {
      setIsSearchingMap(false);
    }
  };

  const eventHandlers = useMemo(() => ({
    dragend() {
      const marker = markerRef.current;
      if (marker != null) {
        const position = marker.getLatLng();
        setLat(position.lat);
        setLng(position.lng);
      }
    },
  }), []);

  // ── HÀM LƯU DỮ LIỆU
  const handleSave = async (e: React.FormEvent) => {
    e.preventDefault();
    setError('');

    if (!name.trim()) return setError('Vui lòng nhập tên chi nhánh.');
    if (!phone.match(/^(0[3|5|7|8|9])+([0-9]{8})\b/)) return setError('Số điện thoại không hợp lệ.');

    let finalAddress = street.trim();
    if (mode === 'create' || (selectedProvince && selectedWard)) {
      if (!selectedProvince || !selectedWard || !street.trim()) {
        return setError('Vui lòng chọn đầy đủ Tỉnh, Phường/Xã và Số nhà.');
      }
      finalAddress = `${street.trim()}, ${selectedWard.name_with_type}, ${selectedProvince.name_with_type}`;
    }

    // ĐÓNG GÓI PAYLOAD KẾT HỢP
    const payload = {
      name: name.trim(),
      phone: phone.trim(),
      address: finalAddress,
      status: status,
      latitude: lat,
      longitude: lng,
      managerId: selectedManagerId ? parseInt(selectedManagerId, 10) : null,
    };

    setIsLoading(true);
    try {
      let savedData;
      if (mode === 'create') {
        savedData = await createBranch(payload);
      } else {
        savedData = await updateBranch(branch.id, payload);
      }
      onSuccess(savedData);
    } catch (err: any) {
      setError(err?.response?.data?.message ?? err.message ?? 'Không thể lưu chi nhánh. Vui lòng thử lại.');
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div className="modal-overlay" style={styles.overlay}>
      <div className="modal-container" style={styles.modal}>

        <div style={styles.header}>
          <h2 style={styles.title}>{mode === 'create' ? 'Thêm Chi Nhánh Mới' : 'Cập Nhật Chi Nhánh'}</h2>
          <button type="button" onClick={onClose} style={styles.closeBtn}><X size={20} /></button>
        </div>

        <div style={styles.body}>
          {error && (
            <div style={styles.errorBox}>
              <AlertCircle size={18} />
              <span>{error}</span>
            </div>
          )}

          <div style={styles.row}>
            <div style={styles.col}>
              <label style={styles.label}>Tên chi nhánh <span style={styles.req}>*</span></label>
              <input value={name} onChange={e => setName(e.target.value)} style={styles.input} disabled={isLoading} placeholder="VD: Chi nhánh Trung Tâm" />
            </div>
            <div style={styles.col}>
              <label style={styles.label}>Số điện thoại <span style={styles.req}>*</span></label>
              <input value={phone} onChange={e => setPhone(e.target.value)} style={styles.input} disabled={isLoading} placeholder="09xxxxxxxx" maxLength={10} />
            </div>
          </div>

          {/* Ô CHỌN QUẢN LÝ (UI MỚI KẾT HỢP LOGIC CŨ) */}
          <div style={styles.sectionTitle}>
            <UserCircle size={18} /> Phân công Quản lý
          </div>
          <div style={styles.row}>
            <div style={styles.col}>
              <label style={styles.label}>Tài khoản Quản lý chi nhánh</label>
              {managersLoading ? (
                <div style={{ fontSize: '0.9rem', color: '#64748b', padding: '10px 0' }}>Đang tải danh sách quản lý...</div>
              ) : managersError ? (
                <div style={{ fontSize: '0.9rem', color: '#ef4444', padding: '10px 0' }}>{managersError}</div>
              ) : (
                <select
                  value={selectedManagerId}
                  onChange={e => setSelectedManagerId(e.target.value)}
                  style={styles.input}
                  disabled={isLoading}
                >
                  <option value="">-- Chưa phân công --</option>
                  {availableManagers.map((mgr) => (
                    <option key={mgr.id} value={String(mgr.id)}>
                      {mgr.fullName ? `${mgr.fullName} - ${mgr.email}` : mgr.email}
                      {branch?.manager?.id === mgr.id ? ' ✓ Hiện tại' : ''}
                    </option>
                  ))}
                </select>
              )}
              <p style={{ margin: '4px 0 0 0', fontSize: '0.8rem', color: '#64748b' }}>
                Chỉ hiển thị các tài khoản chưa được phân công. Có thể bỏ qua và phân công sau.
              </p>
            </div>
          </div>

          <div style={styles.sectionTitle}>
            <MapPin size={18} /> Định vị Khu vực (Chính quyền 2 cấp)
          </div>

          <div style={styles.row}>
            <div style={styles.col}>
              <label style={styles.label}>Tỉnh / Thành phố <span style={styles.req}>*</span></label>
              <select onChange={handleProvinceChange} style={styles.input} defaultValue="" disabled={isLoading}>
                <option value="" disabled>Chọn Tỉnh/Thành</option>
                {provinces.map(p => <option key={p.code} value={p.code}>{p.name}</option>)}
              </select>
            </div>
            <div style={styles.col}>
              <label style={styles.label}>Phường / Xã / Đặc khu <span style={styles.req}>*</span></label>
              <select onChange={handleWardChange} style={styles.input} value={selectedWard?.code || ''} disabled={!selectedProvince || isLoading}>
                <option value="" disabled>Chọn Phường/Xã/Đặc khu</option>
                {wards.map(w => <option key={w.code} value={w.code}>{w.name}</option>)}
              </select>
            </div>
          </div>

          <label style={styles.label}>Số nhà, Tên đường <span style={styles.req}>*</span></label>
          <div style={styles.searchRow}>
            <input
              value={street}
              onChange={e => setStreet(e.target.value)}
              style={{ ...styles.input, flex: 1, marginBottom: 0 }}
              placeholder="VD: 123 Lê Lợi..."
              disabled={isLoading}
            />
            <button type="button" onClick={searchLocation} disabled={isSearchingMap || isLoading} style={styles.searchBtn}>
              <Search size={16} /> {isSearchingMap ? 'Đang tìm...' : 'Tìm Tọa độ'}
            </button>
          </div>
          <p style={styles.hint}>Nhập đầy đủ địa chỉ và bấm "Tìm Tọa độ". Bạn có thể <b>Kéo thả biểu tượng kim đỏ</b> trên bản đồ bên dưới để chọn chính xác vị trí.</p>

          <div style={styles.mapContainer}>
            <MapContainer center={[lat, lng]} zoom={16} style={{ height: '100%', width: '100%', zIndex: 0 }}>
              <TileLayer url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png" />
              <MapUpdater center={[lat, lng]} />
              <Marker position={[lat, lng]} draggable={!isLoading} eventHandlers={eventHandlers} ref={markerRef} />
            </MapContainer>
            <div style={styles.coordsOverlay}>
              Vĩ độ: {lat.toFixed(6)} | Kinh độ: {lng.toFixed(6)}
            </div>
          </div>

          <div style={{ ...styles.row, marginTop: 12 }}>
            <div style={styles.col}>
              <label style={styles.label}>Trạng thái hoạt động</label>
              <select value={status} onChange={e => setStatus(e.target.value)} style={{ ...styles.input, width: '50%' }} disabled={isLoading}>
                <option value="ACTIVE">Đang hoạt động</option>
                <option value="INACTIVE">Tạm khóa</option>
              </select>
            </div>
          </div>
        </div>

        <div style={styles.footer}>
          <button type="button" onClick={onClose} style={styles.cancelBtn} disabled={isLoading}>Hủy bỏ</button>
          <button type="button" onClick={handleSave} style={styles.saveBtn} disabled={isLoading}>
            <Save size={16} /> {isLoading ? 'Đang lưu...' : 'Lưu Chi Nhánh'}
          </button>
        </div>

      </div>
    </div>
  );
};

const styles: Record<string, React.CSSProperties> = {
  overlay: {
    position: 'fixed', top: 0, left: 0, right: 0, bottom: 0,
    backgroundColor: 'rgba(0,0,0,0.5)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 1000,
  },
  modal: {
    backgroundColor: '#fff', borderRadius: '12px', width: '100%', maxWidth: '750px', maxHeight: '90vh',
    display: 'flex', flexDirection: 'column', boxShadow: '0 10px 25px rgba(0,0,0,0.2)',
  },
  header: {
    padding: '20px 24px', borderBottom: '1px solid #e2e8f0', display: 'flex', justifyContent: 'space-between', alignItems: 'center',
    flexShrink: 0,
  },
  title: { margin: 0, fontSize: '1.25rem', fontWeight: 700, color: '#1e293b' },
  closeBtn: { background: 'none', border: 'none', cursor: 'pointer', color: '#64748b' },
  body: { padding: '24px', overflowY: 'auto', flex: 1, display: 'flex', flexDirection: 'column', gap: '16px' },
  row: { display: 'flex', gap: '16px' },
  col: { flex: 1, display: 'flex', flexDirection: 'column' },
  label: { fontSize: '0.875rem', fontWeight: 600, color: '#475569', marginBottom: '6px' },
  req: { color: '#ef4444' },
  input: {
    padding: '10px 14px', border: '1px solid #cbd5e1', borderRadius: '8px', fontSize: '0.95rem',
    outline: 'none', backgroundColor: '#f8fafc',
  },
  sectionTitle: { display: 'flex', alignItems: 'center', gap: '8px', fontSize: '1.1rem', fontWeight: 700, color: '#0f172a', marginTop: '10px', borderBottom: '2px solid #e2e8f0', paddingBottom: '8px' },
  searchRow: { display: 'flex', gap: '10px', alignItems: 'stretch' },
  searchBtn: {
    display: 'flex', alignItems: 'center', gap: '6px', padding: '0 16px', backgroundColor: '#e0f2fe',
    color: '#0284c7', border: '1px solid #7dd3fc', borderRadius: '8px', cursor: 'pointer', fontWeight: 600,
  },
  hint: { margin: 0, fontSize: '0.8rem', color: '#64748b' },
  mapContainer: {
    height: '300px',
    minHeight: '300px',
    flexShrink: 0,
    width: '100%',
    borderRadius: '8px',
    overflow: 'hidden',
    position: 'relative',
    border: '1px solid #cbd5e1'
  },
  coordsOverlay: {
    position: 'absolute', bottom: '10px', left: '10px', zIndex: 400, backgroundColor: 'rgba(255,255,255,0.9)',
    padding: '4px 10px', borderRadius: '6px', fontSize: '0.8rem', fontWeight: 600, border: '1px solid #ccc',
  },
  errorBox: { display: 'flex', alignItems: 'center', gap: '8px', padding: '12px', backgroundColor: '#fef2f2', color: '#b91c1c', borderRadius: '8px', fontSize: '0.9rem', fontWeight: 500 },
  footer: { padding: '16px 24px', borderTop: '1px solid #e2e8f0', display: 'flex', justifyContent: 'flex-end', gap: '12px', backgroundColor: '#f8fafc', borderRadius: '0 0 12px 12px', flexShrink: 0 },
  cancelBtn: { padding: '10px 20px', borderRadius: '8px', border: '1px solid #cbd5e1', backgroundColor: '#fff', color: '#475569', fontWeight: 600, cursor: 'pointer' },
  saveBtn: { display: 'flex', alignItems: 'center', gap: '8px', padding: '10px 24px', borderRadius: '8px', border: 'none', backgroundColor: '#0ea5e9', color: '#fff', fontWeight: 600, cursor: 'pointer' },
};

export default BranchModal;