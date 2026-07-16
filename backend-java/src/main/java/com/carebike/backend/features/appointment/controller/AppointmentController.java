package com.carebike.backend.features.appointment.controller;

import com.carebike.backend.features.appointment.dto.AppointmentRequest;
import com.carebike.backend.features.appointment.entity.Appointment;
import com.carebike.backend.features.appointment.service.AppointmentService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/appointments")
@CrossOrigin(origins = "*")
public class AppointmentController {

    private final AppointmentService appointmentService;

    public AppointmentController(AppointmentService appointmentService) {
        this.appointmentService = appointmentService;
    }

    /**
     * POST /api/appointments
     * Khởi tạo yêu cầu đặt lịch hẹn bảo dưỡng mới từ phía khách hàng.
     */
    @PostMapping
    @org.springframework.security.access.prepost.PreAuthorize("hasAnyRole('CUSTOMER', 'BRANCH', 'ADMIN')")
    public ResponseEntity<Map<String, Object>> createAppointment(@RequestBody AppointmentRequest request) {
        Appointment created = appointmentService.create(request);
        Map<String, Object> resp = toResponse(created);
        
        boolean allBusy = appointmentService.isAllStaffBusy(request.getBranchId());
        resp.put("allStaffBusy", allBusy);
        
        return ResponseEntity.ok(resp);
    }

    /**
     * GET /api/appointments/customer/{customerId} — list appointments for a customer
     */
    @GetMapping("/customer/{customerId}")
    @org.springframework.security.access.prepost.PreAuthorize("hasRole('CUSTOMER')")
    public ResponseEntity<List<Map<String, Object>>> getByCustomer(@PathVariable Integer customerId) {
        return ResponseEntity.ok(appointmentService.getByCustomerId(customerId)
                .stream()
                .map(this::toResponse)
                .toList());
    }

    /**
     * PUT /api/appointments/{id}/cancel
     * Hủy lịch hẹn bảo dưỡng. Thao tác này được thực hiện bởi người dùng (Customer).
     */
    @PutMapping("/{id}/cancel")
    public ResponseEntity<?> cancelAppointment(@PathVariable Integer id) {
        Appointment cancelled = appointmentService.cancel(id);
        return ResponseEntity.ok(cancelled);
    }

    /**
     * GET /api/appointments/branch/{branchId}?status=PENDING
     */
    @GetMapping("/branch/{branchId}")
    @org.springframework.security.access.prepost.PreAuthorize("hasAnyRole('BRANCH', 'ADMIN')")
    public ResponseEntity<List<Map<String, Object>>> getByBranchAndStatus(
            @PathVariable Integer branchId,
            @RequestParam(required = false) String status) {
        if (status == null || status.isEmpty()) {
            return ResponseEntity.ok(appointmentService.getByBranchId(branchId)
                    .stream()
                    .map(this::toResponse)
                    .toList());
        }
        return ResponseEntity.ok(appointmentService.getByBranchIdAndStatus(branchId, status)
                .stream()
                .map(this::toResponse)
                .toList());
    }

    /**
     * PUT /api/appointments/{id}/status
     * Chi nhánh cập nhật trạng thái xử lý lịch hẹn (ví dụ: CONFIRMED, CANCELLED).
     * Yêu cầu kiểm tra tính hợp lệ của tham số trạng thái trước khi thực thi.
     */
    @PutMapping("/{id}/status")
    @org.springframework.security.access.prepost.PreAuthorize("hasAnyRole('BRANCH', 'ADMIN')")
    public ResponseEntity<?> updateStatus(@PathVariable Integer id, @RequestBody Map<String, String> request) {
        String status = request.get("status");
        if (status == null || status.isEmpty()) {
            throw new RuntimeException("Trạng thái không được để trống.");
        }
        Appointment updated = appointmentService.updateStatus(id, status);
        return ResponseEntity.ok(updated);
    }

    @PostMapping("/invoice")
    @org.springframework.security.access.prepost.PreAuthorize("hasAnyRole('BRANCH', 'ADMIN')")
    public ResponseEntity<Map<String, Object>> saveInvoice(@RequestBody Map<String, Object> request) {
        Appointment saved = appointmentService.saveInvoice(request);
        return ResponseEntity.ok(toResponse(saved));
    }

    @PutMapping("/{id}/pay")
    @org.springframework.security.access.prepost.PreAuthorize("hasAnyRole('BRANCH', 'ADMIN')")
    public ResponseEntity<Map<String, Object>> pay(@PathVariable Integer id) {
        com.carebike.backend.features.maintenance.entity.MaintenanceHistory history = appointmentService.pay(id);
        Map<String, Object> response = new LinkedHashMap<>();
        response.put("message", "Thanh toán thành công");
        response.put("historyId", history.getId());
        return ResponseEntity.ok(response);
    }

    private Map<String, Object> toResponse(Appointment appointment) {
        Map<String, Object> response = new LinkedHashMap<>();
        response.put("id", appointment.getId());
        response.put("appointmentDate", appointment.getAppointmentDate());
        response.put("note", appointment.getNote());
        response.put("status", appointment.getStatus());
        response.put("customerId", appointment.getCustomerId());
        response.put("customerName", appointment.getCustomerName());
        response.put("customerPhone", appointment.getCustomerPhone());
        response.put("branchId", appointment.getBranchId());
        response.put("branchName", appointment.getBranchName());
        response.put("vehicleId", appointment.getVehicleId());
        response.put("vehicleName", appointment.getVehicleName());
        response.put("vehicleBrand", appointment.getVehicleBrand());
        response.put("vehiclePlate", appointment.getVehiclePlate());
        response.put("engineCapacity", appointment.getEngineCapacity());
        response.put("assignedStaffId", appointment.getAssignedStaffId());
        response.put("assignedStaffCode", appointment.getAssignedStaffCode());
        response.put("assignedStaffName", appointment.getAssignedStaffName());

        response.put("invoiceDetails", appointment.getInvoiceDetails());
        response.put("totalCost", appointment.getTotalCost());
        response.put("currentKm", appointment.getCurrentKm());
        response.put("completedAt", appointment.getCompletedAt());
        return response;
    }
}
