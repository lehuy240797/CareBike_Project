package com.carebike.backend.features.branch.controller;

import com.carebike.backend.features.branch.dto.BranchRequest;
import com.carebike.backend.features.branch.entity.Branch;
import com.carebike.backend.features.branch.service.BranchService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/branches")
@CrossOrigin(origins = "http://localhost:5173")
public class BranchController {

    private final BranchService branchService;

    public BranchController(BranchService branchService) {
        this.branchService = branchService;
    }

    /** GET /api/branches — list all branches */
    @GetMapping
    public ResponseEntity<List<Branch>> getAllBranches() {
        return ResponseEntity.ok(branchService.getAllBranches());
    }

    /**
     * POST /api/branches — create a branch + provision manager account in one transaction.
     * Returns 400 with a Vietnamese error message on validation/uniqueness failures.
     */
    @PostMapping
    public ResponseEntity<?> createBranch(@RequestBody BranchRequest request) {
        try {
            Branch created = branchService.create(request);
            return ResponseEntity.ok(created);
        } catch (RuntimeException e) {
            return ResponseEntity.badRequest()
                    .body(Map.of("message", e.getMessage()));
        }
    }

    /**
     * PUT /api/branches/{id} — update branch info + reassign manager.
     * Returns 400 with error message on failure.
     */
    @PutMapping("/{id}")
    public ResponseEntity<?> updateBranch(
            @PathVariable Integer id,
            @RequestBody BranchRequest request) {
        try {
            Branch updated = branchService.update(id, request);
            return ResponseEntity.ok(updated);
        } catch (RuntimeException e) {
            return ResponseEntity.badRequest()
                    .body(Map.of("message", e.getMessage()));
        }
    }

    /** DELETE /api/branches/{id} — delete a branch */
    @DeleteMapping("/{id}")
    public ResponseEntity<Void> deleteBranch(@PathVariable Integer id) {
        try {
            branchService.delete(id);
            return ResponseEntity.noContent().build();
        } catch (RuntimeException e) {
            return ResponseEntity.notFound().build();
        }
    }
}