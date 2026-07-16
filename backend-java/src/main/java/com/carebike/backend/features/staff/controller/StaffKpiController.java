package com.carebike.backend.features.staff.controller;

import com.carebike.backend.features.staff.dto.StaffKpiResponse;
import com.carebike.backend.features.staff.service.StaffKpiService;
import org.springframework.http.ResponseEntity;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.time.LocalDate;

@RestController
@RequestMapping("/api/staff")
@CrossOrigin(origins = "*")
public class StaffKpiController {

    private final StaffKpiService staffKpiService;

    public StaffKpiController(StaffKpiService staffKpiService) {
        this.staffKpiService = staffKpiService;
    }

    @GetMapping("/branch/{branchId}/kpi")
    public ResponseEntity<List<StaffKpiResponse>> getBranchStaffKpis(
            @PathVariable Integer branchId,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to
    ) {
        return ResponseEntity.ok(staffKpiService.getBranchKpis(branchId, from, to));
    }

}
