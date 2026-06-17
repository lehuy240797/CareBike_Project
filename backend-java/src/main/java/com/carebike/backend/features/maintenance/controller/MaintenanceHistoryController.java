package com.carebike.backend.features.maintenance.controller;

import com.carebike.backend.features.maintenance.dto.MaintenanceHistoryRequest;
import com.carebike.backend.features.maintenance.entity.MaintenanceHistory;
import com.carebike.backend.features.maintenance.service.MaintenanceHistoryService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/maintenance")
public class MaintenanceHistoryController {

    private final MaintenanceHistoryService maintenanceService;

    public MaintenanceHistoryController(MaintenanceHistoryService maintenanceService) {
        this.maintenanceService = maintenanceService;
    }

    /**
     * GET /api/maintenance/customer/{userId}
     * Fetch all maintenance records for a given customer, sorted newest first.
     */
    @GetMapping("/customer/{userId}")
    public ResponseEntity<List<MaintenanceHistory>> getByCustomer(@PathVariable Integer userId) {
        List<MaintenanceHistory> records = maintenanceService.getByCustomerId(userId);
        return ResponseEntity.ok(records);
    }

    /**
     * POST /api/maintenance
     * Create a new maintenance record.
     */
    @PostMapping
    public ResponseEntity<MaintenanceHistory> createRecord(
            @RequestBody MaintenanceHistoryRequest request) {
        MaintenanceHistory saved = maintenanceService.create(request);
        return ResponseEntity.ok(saved);
    }
}
