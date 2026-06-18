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
     * POST /api/branches
     * Xử lý tạo mới chi nhánh và cấp phát tài khoản quản lý (Manager) trong cùng một Transaction.
     */
    @PostMapping
    public ResponseEntity<?> createBranch(@RequestBody BranchRequest request) {
        Branch created = branchService.create(request);
        return ResponseEntity.ok(created);
    }

    /**
     * PUT /api/branches/{id}
     * Cập nhật thông tin chi nhánh và điều chuyển người quản lý.
     * Đảm bảo tính nhất quán dữ liệu thông qua Transaction tại tầng Service.
     */
    @PutMapping("/{id}")
    public ResponseEntity<?> updateBranch(
            @PathVariable Integer id,
            @RequestBody BranchRequest request) {
        Branch updated = branchService.update(id, request);
        return ResponseEntity.ok(updated);
    }

    /** 
     * DELETE /api/branches/{id}
     * Xóa chi nhánh và vô hiệu hóa/xóa các tài khoản quản lý liên quan.
     */
    @DeleteMapping("/{id}")
    public ResponseEntity<Void> deleteBranch(@PathVariable Integer id) {
        branchService.delete(id);
        return ResponseEntity.noContent().build();
    }
}