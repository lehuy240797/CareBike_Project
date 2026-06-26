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
import { btnOutline, btnPrimary, inputBase, selectBase } from '../../ui/styles';

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
      setManagersError('Could not load the manager list.');
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
      setError('Please enter an address to search.');
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
        setError('Location not found. Please drag the red pin manually.');
      }
    } catch (err) {
      setError('Map connection error.');
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

  // ── SAVE DATA FUNCTION
  const handleSave = async (e: React.FormEvent) => {
    e.preventDefault();
    setError('');

    if (!name.trim()) return setError('Please enter the branch name.');
    if (!phone.match(/^(0[3|5|7|8|9])+([0-9]{8})\b/)) return setError('Invalid phone number.');

    let finalAddress = street.trim();
    if (mode === 'create' || (selectedProvince && selectedWard)) {
      if (!selectedProvince || !selectedWard || !street.trim()) {
        return setError('Please select Province, Ward and Street.');
      }
      finalAddress = `${street.trim()}, ${selectedWard.name_with_type}, ${selectedProvince.name_with_type}`;
    }

    // BUILD THE COMBINED PAYLOAD
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
      setError(err?.response?.data?.message ?? err.message ?? 'Could not save the branch. Please try again.');
    } finally {
      setIsLoading(false);
    }
  };

  const sectionTitle =
    'mt-2.5 flex items-center gap-2 border-b-2 border-edge pb-2 text-[1.1rem] font-bold text-ink [&_svg]:text-primary';
  const fieldLabel = 'mb-1.5 text-sm font-semibold text-ink';

  return (
    <div className="fixed inset-0 z-[1000] flex items-center justify-center bg-[rgba(15,23,42,0.55)] p-4 backdrop-blur-[4px] animate-fade-in">
      <div className="relative flex max-h-[90vh] w-full max-w-[750px] flex-col overflow-hidden rounded-[18px] bg-white shadow-float animate-scale-in">
        {/* Top gradient accent */}
        <div className="absolute inset-x-0 top-0 z-[1] h-1 bg-gradient-to-r from-primary-bright via-primary to-primary-hover" />

        <div className="flex shrink-0 items-center justify-between border-b border-edge px-6 py-5">
          <h2 className="m-0 font-display text-xl font-bold text-ink">{mode === 'create' ? 'Add New Branch' : 'Update Branch'}</h2>
          <button type="button" onClick={onClose} className="flex h-8 w-8 shrink-0 items-center justify-center rounded-[10px] border-none bg-transparent text-ink-muted transition-all duration-200 ease-spring hover:rotate-90 hover:bg-primary-light hover:text-primary"><X size={20} /></button>
        </div>

        <div className="flex flex-1 flex-col gap-4 overflow-y-auto p-6">
          {error && (
            <div className="flex items-center gap-2 rounded-[10px] border border-red-200 bg-red-50 px-3 py-3 text-sm font-medium text-red-600">
              <AlertCircle size={18} />
              <span>{error}</span>
            </div>
          )}

          <div className="flex flex-col gap-4 sm:flex-row">
            <div className="flex flex-1 flex-col">
              <label className={fieldLabel}>Branch name <span className="text-red-600">*</span></label>
              <input value={name} onChange={e => setName(e.target.value)} className={inputBase} disabled={isLoading} placeholder="e.g. Central Branch" />
            </div>
            <div className="flex flex-1 flex-col">
              <label className={fieldLabel}>Phone number <span className="text-red-600">*</span></label>
              <input value={phone} onChange={e => setPhone(e.target.value)} className={inputBase} disabled={isLoading} placeholder="09xxxxxxxx" maxLength={10} />
            </div>
          </div>

          {/* MANAGER SELECT (new UI combined with existing logic) */}
          <div className={sectionTitle}>
            <UserCircle size={18} /> Assign Manager
          </div>
          <div className="flex flex-col gap-4 sm:flex-row">
            <div className="flex flex-1 flex-col">
              <label className={fieldLabel}>Branch manager account</label>
              {managersLoading ? (
                <div className="py-2.5 text-[0.9rem] text-ink-muted">Loading manager list...</div>
              ) : managersError ? (
                <div className="py-2.5 text-[0.9rem] text-red-600">{managersError}</div>
              ) : (
                <select
                  value={selectedManagerId}
                  onChange={e => setSelectedManagerId(e.target.value)}
                  className={selectBase}
                  disabled={isLoading}
                >
                  <option value="">-- Unassigned --</option>
                  {availableManagers.map((mgr) => (
                    <option key={mgr.id} value={String(mgr.id)}>
                      {mgr.fullName ? `${mgr.fullName} - ${mgr.email}` : mgr.email}
                      {branch?.manager?.id === mgr.id ? ' ✓ Current' : ''}
                    </option>
                  ))}
                </select>
              )}
              <p className="mt-1 text-[0.8rem] text-ink-muted">
                Only unassigned accounts are shown. You can skip and assign later.
              </p>
            </div>
          </div>

          <div className={sectionTitle}>
            <MapPin size={18} /> Locate Area (2-tier administrative)
          </div>

          <div className="flex flex-col gap-4 sm:flex-row">
            <div className="flex flex-1 flex-col">
              <label className={fieldLabel}>Province / City <span className="text-red-600">*</span></label>
              <select onChange={handleProvinceChange} className={selectBase} defaultValue="" disabled={isLoading}>
                <option value="" disabled>Select Province/City</option>
                {provinces.map(p => <option key={p.code} value={p.code}>{p.name}</option>)}
              </select>
            </div>
            <div className="flex flex-1 flex-col">
              <label className={fieldLabel}>Ward / Commune <span className="text-red-600">*</span></label>
              <select onChange={handleWardChange} className={selectBase} value={selectedWard?.code || ''} disabled={!selectedProvince || isLoading}>
                <option value="" disabled>Select Ward/Commune</option>
                {wards.map(w => <option key={w.code} value={w.code}>{w.name}</option>)}
              </select>
            </div>
          </div>

          <label className={fieldLabel}>Street address <span className="text-red-600">*</span></label>
          <div className="flex items-stretch gap-2.5">
            <input
              value={street}
              onChange={e => setStreet(e.target.value)}
              className={`${inputBase} flex-1`}
              placeholder="e.g. 123 Main St..."
              disabled={isLoading}
            />
            <button type="button" onClick={searchLocation} disabled={isSearchingMap || isLoading} className="flex items-center gap-1.5 rounded-[10px] border border-primary-muted bg-primary-light px-4 font-semibold text-primary transition-colors hover:bg-primary-muted disabled:opacity-60">
              <Search size={16} /> {isSearchingMap ? 'Searching...' : 'Find Coordinates'}
            </button>
          </div>
          <p className="m-0 text-[0.8rem] text-ink-muted">Enter the full address and click "Find Coordinates". You can <b>drag the red pin</b> on the map below to pick the exact location.</p>

          <div className="relative h-[300px] min-h-[300px] w-full shrink-0 overflow-hidden rounded-[10px] border border-edge">
            <MapContainer center={[lat, lng]} zoom={16} style={{ height: '100%', width: '100%', zIndex: 0 }}>
              <TileLayer url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png" />
              <MapUpdater center={[lat, lng]} />
              <Marker position={[lat, lng]} draggable={!isLoading} eventHandlers={eventHandlers} ref={markerRef} />
            </MapContainer>
            <div className="absolute bottom-2.5 left-2.5 z-[400] rounded-md border border-stone-300 bg-white/90 px-2.5 py-1 text-[0.8rem] font-semibold">
              Lat: {lat.toFixed(6)} | Lng: {lng.toFixed(6)}
            </div>
          </div>

          <div className="mt-3 flex flex-col gap-4 sm:flex-row">
            <div className="flex flex-1 flex-col">
              <label className={fieldLabel}>Operating status</label>
              <select value={status} onChange={e => setStatus(e.target.value)} className={`${selectBase} w-1/2`} disabled={isLoading}>
                <option value="ACTIVE">Active</option>
                <option value="INACTIVE">Suspended</option>
              </select>
            </div>
          </div>
        </div>

        <div className="flex shrink-0 justify-end gap-3 border-t border-edge bg-canvas px-6 py-4">
          <button type="button" onClick={onClose} className={btnOutline} disabled={isLoading}>Cancel</button>
          <button type="button" onClick={handleSave} className={btnPrimary} disabled={isLoading}>
            <Save size={16} /> {isLoading ? 'Saving...' : 'Save Branch'}
          </button>
        </div>

      </div>
    </div>
  );
};

export default BranchModal;