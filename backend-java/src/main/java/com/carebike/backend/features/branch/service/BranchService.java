package com.carebike.backend.features.branch.service;

import com.carebike.backend.features.auth.entity.User;
import com.carebike.backend.features.auth.repository.UserRepository;
import com.carebike.backend.features.branch.dto.BranchRequest;
import com.carebike.backend.features.branch.entity.Branch;
import com.carebike.backend.features.branch.repository.BranchRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Optional;

@Service
public class BranchService {

    private final BranchRepository branchRepository;
    private final UserRepository userRepository;

    public BranchService(BranchRepository branchRepository, UserRepository userRepository) {
        this.branchRepository = branchRepository;
        this.userRepository = userRepository;
    }

    /** Lấy tất cả chi nhánh */
    public List<Branch> getAllBranches() {
        return branchRepository.findAll();
    }

    /** Lấy chi nhánh theo ID */
    public Optional<Branch> getById(Integer id) {
        return branchRepository.findById(id);
    }

    /// Tạo chi nhánh mới
    @Transactional
    public Branch create(BranchRequest request) {
        Branch branch = new Branch();
        applyBranchFields(branch, request);
        
        if (request.getManagerId() != null) {
            User manager = userRepository.findById(request.getManagerId())
                .orElseThrow(() -> new RuntimeException("Không tìm thấy Quản lý với ID: " + request.getManagerId()));
            branch.setManager(manager);
        }
        
        return branchRepository.save(branch);
    }

    /** CẬP NHẬT CHI NHÁNH */
    @Transactional
    public Branch update(Integer id, BranchRequest request) {
        Branch branch = branchRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Không tìm thấy chi nhánh: " + id));
        applyBranchFields(branch, request);

        if (request.getManagerId() != null) {
            Integer newManagerId = request.getManagerId();

            branchRepository.findByManagerId(newManagerId).ifPresent(otherBranch -> {
                if (!otherBranch.getId().equals(id)) {
                    otherBranch.setManager(null);
                    branchRepository.saveAndFlush(otherBranch); 
                }
            });

            User newManager = userRepository.findById(newManagerId)
                    .orElseThrow(() -> new RuntimeException("Không tìm thấy tài khoản quản lý: " + newManagerId));
            branch.setManager(newManager);

        } else {
            branch.setManager(null);
        }

        return branchRepository.save(branch);
    }

    public void delete(Integer id) {
        if (!branchRepository.existsById(id)) {
            throw new RuntimeException("Không tìm thấy chi nhánh: " + id);
        }
        try {
            branchRepository.deleteById(id);
            branchRepository.flush(); // Cần flush để trigger exception ngay lập tức
        } catch (org.springframework.dao.DataIntegrityViolationException e) {
            throw new RuntimeException("Cannot delete this branch because it has associated data (staff, shifts, invoices...). Please change status to INACTIVE instead.");
        }
    }

    // Nơi nhận dữ liệu: Nhận trực tiếp Tọa độ siêu chuẩn từ Frontend
    private void applyBranchFields(Branch branch, BranchRequest request) {
        branch.setName(request.getName());
        branch.setAddress(request.getAddress());
        branch.setPhone(request.getPhone());
        branch.setStatus(request.getStatus() != null ? request.getStatus() : "ACTIVE");
        
        // Chỉ việc lấy tọa độ từ React ném thẳng vào Database, cực kỳ nhẹ server!
        branch.setLatitude(request.getLatitude());
        branch.setLongitude(request.getLongitude());
    }
}