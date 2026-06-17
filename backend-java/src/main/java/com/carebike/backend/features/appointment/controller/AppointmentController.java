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
     * POST /api/appointments — book a new appointment (mobile customers)
     */
    @PostMapping
    @org.springframework.security.access.prepost.PreAuthorize("hasRole('CUSTOMER')")
    public ResponseEntity<?> createAppointment(@RequestBody AppointmentRequest request) {
        try {
            Appointment created = appointmentService.create(request);
            return ResponseEntity.ok(created);
        } catch (RuntimeException e) {
            return ResponseEntity.badRequest().body(Map.of("message", e.getMessage()));
        }
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
     * PUT /api/appointments/{id}/cancel — customer cancels their appointment
     */
    @PutMapping("/{id}/cancel")
    public ResponseEntity<?> cancelAppointment(@PathVariable Integer id) {
        try {
            Appointment cancelled = appointmentService.cancel(id);
            return ResponseEntity.ok(cancelled);
        } catch (RuntimeException e) {
            return ResponseEntity.badRequest().body(Map.of("message", e.getMessage()));
        }
    }

    /**
     * GET /api/appointments/branch/{branchId}?status=PENDING
     */
    @GetMapping("/branch/{branchId}")
    @org.springframework.security.access.prepost.PreAuthorize("hasAnyRole('BRANCH', 'ADMIN')")
    public ResponseEntity<List<Appointment>> getByBranchAndStatus(
            @PathVariable Integer branchId,
            @RequestParam String status) {
        return ResponseEntity.ok(appointmentService.getByBranchIdAndStatus(branchId, status));
    }

    /**
     * PUT /api/appointments/{id}/status — branch updates status (CONFIRMED, CANCELLED)
     */
    @PutMapping("/{id}/status")
    @org.springframework.security.access.prepost.PreAuthorize("hasAnyRole('BRANCH', 'ADMIN')")
    public ResponseEntity<?> updateStatus(@PathVariable Integer id, @RequestBody Map<String, String> request) {
        try {
            String status = request.get("status");
            if (status == null || status.isEmpty()) {
                throw new RuntimeException("Trạng thái không được để trống.");
            }
            Appointment updated = appointmentService.updateStatus(id, status);
            return ResponseEntity.ok(updated);
        } catch (RuntimeException e) {
            return ResponseEntity.badRequest().body(Map.of("message", e.getMessage()));
        }
    }
}
