package com.carebike.backend.features.appointment.controller;

import com.carebike.backend.features.appointment.dto.AppointmentRequest;
import com.carebike.backend.features.appointment.entity.Appointment;
import com.carebike.backend.features.appointment.service.AppointmentService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

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
    @org.springframework.security.access.prepost.PreAuthorize("hasRole('CUSTOMER')")
    public ResponseEntity<?> createAppointment(@RequestBody AppointmentRequest request) {
        Appointment created = appointmentService.create(request);
        return ResponseEntity.ok(created);
    }

    /**
     * GET /api/appointments/customer/{customerId} — list appointments for a customer
     */
    @GetMapping("/customer/{customerId}")
    @org.springframework.security.access.prepost.PreAuthorize("hasRole('CUSTOMER')")
    public ResponseEntity<List<Appointment>> getByCustomer(@PathVariable Integer customerId) {
        return ResponseEntity.ok(appointmentService.getByCustomerId(customerId));
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
    public ResponseEntity<List<Appointment>> getByBranchAndStatus(
            @PathVariable Integer branchId,
            @RequestParam(required = false) String status) {
        if (status == null || status.isEmpty()) {
            return ResponseEntity.ok(appointmentService.getByBranchId(branchId));
        }
        return ResponseEntity.ok(appointmentService.getByBranchIdAndStatus(branchId, status));
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
}
