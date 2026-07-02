package com.carebike.backend.features.vehicle.service;

import com.carebike.backend.features.auth.entity.User;
import com.carebike.backend.features.auth.repository.UserRepository;
import com.carebike.backend.features.vehicle.dto.VehicleRequest;
import com.carebike.backend.features.vehicle.entity.Vehicle;
import com.carebike.backend.features.vehicle.repository.VehicleRepository;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.Optional;

@Service
public class VehicleService {

    private final VehicleRepository vehicleRepository;
    private final UserRepository userRepository;

    public VehicleService(VehicleRepository vehicleRepository, UserRepository userRepository) {
        this.vehicleRepository = vehicleRepository;
        this.userRepository = userRepository;
    }

    /** 1. Lấy danh sách toàn bộ xe của 1 Khách hàng */
    public List<Vehicle> getByOwnerId(Integer ownerId) {
        return vehicleRepository.findByOwnerId(ownerId);
    }

    /** 2. Thêm xe mới hoặc Cập nhật xe cũ */
    public Vehicle saveVehicle(Integer ownerId, VehicleRequest request) {
        User owner = userRepository.findById(ownerId)
                .orElseThrow(() -> new RuntimeException("Không tìm thấy người dùng."));

        Vehicle vehicle;
        // Nếu có ID truyền lên -> Đây là hành động Sửa xe cũ
        if (request.getId() != null) {
            vehicle = vehicleRepository.findById(request.getId())
                    .orElseThrow(() -> new RuntimeException("Không tìm thấy xe để cập nhật."));
        } else {
            // Nếu không có ID -> Đây là hành động Thêm xe mới
            vehicle = new Vehicle();
            vehicle.setOwner(owner);
        }

        vehicle.setBrand(request.getBrand());
        vehicle.setVehicleType(request.getVehicleType());
        vehicle.setVehicleName(request.getVehicleName());
        
        // 3 trường mới thay thế cho số khung, số máy
        vehicle.setLicensePlate(request.getLicensePlate());
        vehicle.setEngineCapacity(request.getEngineCapacity());
        vehicle.setCurrentKm(request.getCurrentKm());

        return vehicleRepository.save(vehicle);
    }

    /** 3. Tìm kiếm xe bằng Biển số (Dành cho Chi nhánh quét mã) */
    public Optional<Vehicle> getByLicensePlate(String licensePlate) {
        return vehicleRepository.findByLicensePlate(licensePlate);
    }

    /** 4. Xóa xe */
    public void deleteVehicle(Integer vehicleId) {
        if (!vehicleRepository.existsById(vehicleId)) {
            throw new RuntimeException("Không tìm thấy xe để xóa.");
        }
        try {
            vehicleRepository.deleteById(vehicleId);
        } catch (Exception e) {
            throw new RuntimeException("Không thể xóa xe này vì nó đã được sử dụng trong lịch hẹn hoặc hóa đơn cứu hộ.");
        }
    }
}