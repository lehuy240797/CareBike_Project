package com.carebike.backend.features.admin.controller;

import com.carebike.backend.features.auth.repository.UserRepository;
import com.carebike.backend.features.branch.repository.BranchRepository;
import com.carebike.backend.features.category.repository.CategoryRepository;
import com.carebike.backend.features.sparepart.repository.SparePartRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.HashMap;
import java.util.Map;

@RestController
@RequestMapping("/api/admin/stats")
public class AdminStatsController {

    @Autowired
    private BranchRepository branchRepository;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private CategoryRepository categoryRepository;

    @Autowired
    private SparePartRepository sparePartRepository;

    @GetMapping
    public ResponseEntity<Map<String, Long>> getAdminStats() {
        Map<String, Long> stats = new HashMap<>();
        stats.put("branches", branchRepository.count());
        stats.put("customers", (long) userRepository.findByRoleRoleName("CUSTOMER").size());
        stats.put("categories", categoryRepository.count());
        stats.put("spareParts", sparePartRepository.count());
        
        return ResponseEntity.ok(stats);
    }
}
