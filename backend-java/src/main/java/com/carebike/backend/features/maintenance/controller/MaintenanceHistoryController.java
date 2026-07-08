package com.carebike.backend.features.maintenance.controller;

import com.carebike.backend.features.maintenance.dto.MaintenanceHistoryRequest;
import com.carebike.backend.features.maintenance.entity.MaintenanceHistory;
import com.carebike.backend.features.maintenance.service.MaintenanceHistoryService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

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
    public ResponseEntity<List<Map<String, Object>>> getByCustomer(@PathVariable Integer userId) {
        List<MaintenanceHistory> records = maintenanceService.getByCustomerId(userId);
        return ResponseEntity.ok(records.stream().map(this::toResponse).toList());
    }

    /**
     * POST /api/maintenance
     * Create a new maintenance record.
     */
    @PostMapping
    public ResponseEntity<Map<String, Object>> createRecord(
            @RequestBody MaintenanceHistoryRequest request) {
        MaintenanceHistory saved = maintenanceService.create(request);
        return ResponseEntity.ok(toResponse(saved));
    }

    private Map<String, Object> toResponse(MaintenanceHistory record) {
        Map<String, Object> response = new LinkedHashMap<>();
        response.put("id", record.getId());
        response.put("serviceDate", record.getServiceDate());
        response.put("currentKm", record.getCurrentKm());
        response.put("serviceDetails", record.getServiceDetails());
        response.put("totalCost", record.getTotalCost());

        if (record.getCustomer() != null) {
            Map<String, Object> customer = new LinkedHashMap<>();
            customer.put("id", record.getCustomer().getId());
            customer.put("fullName", record.getCustomer().getFullName());
            customer.put("phone", record.getCustomer().getPhone());
            response.put("customer", customer);
            response.put("customerId", record.getCustomer().getId());
            response.put("customerName", record.getCustomer().getFullName());
        }

        if (record.getBranch() != null) {
            Map<String, Object> branch = new LinkedHashMap<>();
            branch.put("id", record.getBranch().getId());
            branch.put("name", record.getBranch().getName());
            response.put("branch", branch);
            response.put("branchId", record.getBranch().getId());
            response.put("branchName", record.getBranch().getName());
        }

        return response;
    }
}
