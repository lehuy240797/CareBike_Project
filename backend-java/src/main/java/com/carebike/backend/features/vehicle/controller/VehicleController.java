package com.carebike.backend.features.vehicle.controller;

import com.carebike.backend.features.vehicle.dto.VehicleRequest;
import com.carebike.backend.features.vehicle.entity.Vehicle;
import com.carebike.backend.features.vehicle.service.VehicleService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List; // Phải import List

@RestController
@RequestMapping("/api/vehicles")
public class VehicleController {

    private final VehicleService vehicleService;

    public VehicleController(VehicleService vehicleService) {
        this.vehicleService = vehicleService;
    }

    /**
     * GET /api/vehicles/owner/{userId}
     * Fetch all vehicle profiles for a specific customer.
     * Trả về List (Danh sách), nếu khách chưa có xe thì trả về mảng rỗng []
     */
    @GetMapping("/owner/{userId}")
    public ResponseEntity<List<Vehicle>> getVehicleByOwner(@PathVariable Integer userId) {
        // Hứng danh sách xe và trả về thẳng OK
        List<Vehicle> vehicles = vehicleService.getByOwnerId(userId);
        return ResponseEntity.ok(vehicles);
    }

    /**
     * PUT /api/vehicles/owner/{userId}
     * Khởi tạo hoặc cập nhật hồ sơ phương tiện của khách hàng.
     * Xử lý ngoại lệ ConstraintViolation (như trùng biển số) được thực hiện tại tầng GlobalExceptionHandler.
     */
   @PutMapping("/owner/{userId}")
    public ResponseEntity<?> saveVehicle(
            @PathVariable Integer userId,
            @RequestBody VehicleRequest request) {
        Vehicle saved = vehicleService.saveVehicle(userId, request);
        return ResponseEntity.ok(saved);
    }

    /**
     * GET /api/vehicles/lookup?licensePlate=...
     * Tìm xe theo Biển số (Dành cho chức năng quét mã của Chi nhánh)
     */
    @GetMapping("/lookup")
    public ResponseEntity<Vehicle> lookupVehicle(@RequestParam String licensePlate) {
        // Tìm bằng biển số thì trả về 1 chiếc (Optional), nên dùng .map().orElse() là chuẩn xác!
        return vehicleService.getByLicensePlate(licensePlate)
                .map(ResponseEntity::ok)
                .orElse(ResponseEntity.notFound().build());
    }

    /**
     * DELETE /api/vehicles/{id}
     * Xóa phương tiện khỏi hệ thống (Khách hàng tự xóa xe không dùng nữa)
     */
    @DeleteMapping("/{id}")
    public ResponseEntity<?> deleteVehicle(@PathVariable Integer id) {
        vehicleService.deleteVehicle(id);
        return ResponseEntity.ok().body(java.util.Map.of("message", "Xóa xe thành công"));
    }
}