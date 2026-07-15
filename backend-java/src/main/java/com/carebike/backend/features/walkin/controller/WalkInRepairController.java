package com.carebike.backend.features.walkin.controller;

import com.carebike.backend.features.walkin.dto.WalkInRepairRequest;
import com.carebike.backend.features.walkin.entity.WalkInRepair;
import com.carebike.backend.features.walkin.service.WalkInRepairService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/walk-in-repairs")
@CrossOrigin(origins = "*")
public class WalkInRepairController {

    private final WalkInRepairService walkInRepairService;

    public WalkInRepairController(WalkInRepairService walkInRepairService) {
        this.walkInRepairService = walkInRepairService;
    }

    @GetMapping("/branch/{branchId}")
    @org.springframework.security.access.prepost.PreAuthorize("hasAnyRole('BRANCH', 'ADMIN')")
    public ResponseEntity<List<Map<String, Object>>> getByBranch(@PathVariable Integer branchId) {
        return ResponseEntity.ok(
                walkInRepairService.getByBranch(branchId)
                        .stream()
                        .map(this::toResponse)
                        .toList()
        );
    }

    @PostMapping
    @org.springframework.security.access.prepost.PreAuthorize("hasAnyRole('BRANCH', 'ADMIN')")
    public ResponseEntity<Map<String, Object>> create(@RequestBody WalkInRepairRequest request) {
        return ResponseEntity.ok(toResponse(walkInRepairService.create(request)));
    }

    @PutMapping("/{id}/complete")
    @org.springframework.security.access.prepost.PreAuthorize("hasAnyRole('BRANCH', 'ADMIN')")
    public ResponseEntity<Map<String, Object>> complete(@PathVariable Integer id) {
        return ResponseEntity.ok(toResponse(walkInRepairService.complete(id)));
    }

    private Map<String, Object> toResponse(WalkInRepair repair) {
        Map<String, Object> response = new LinkedHashMap<>();
        response.put("id", repair.getId());
        response.put("type", "WALK_IN");
        response.put("appointmentDate", repair.getRepairDate());
        response.put("note", "Walk-in repair order");
        response.put("status", repair.getStatus());
        response.put("customerName", repair.getCustomerName());
        response.put("customerPhone", repair.getCustomerPhone());
        response.put("branchId", repair.getBranch() != null ? repair.getBranch().getId() : null);
        response.put("branchName", repair.getBranch() != null ? repair.getBranch().getName() : null);
        response.put("vehicleName", repair.getVehicleName());
        response.put("vehiclePlate", repair.getVehiclePlate());
        response.put("engineCapacity", repair.getEngineCapacity());
        response.put("currentKm", repair.getCurrentKm());
        response.put("staffCode", repair.getStaffCode());
        response.put("staffName", repair.getStaffName());
        response.put("invoiceDetails", repair.getInvoiceDetails());
        response.put("totalCost", repair.getTotalCost());
        response.put("completedAt", repair.getCompletedAt());
        return response;
    }
}
