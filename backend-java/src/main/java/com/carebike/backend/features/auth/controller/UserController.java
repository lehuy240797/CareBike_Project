package com.carebike.backend.features.auth.controller;

import com.carebike.backend.features.auth.entity.User;
import com.carebike.backend.features.auth.repository.UserRepository;
import com.carebike.backend.features.branch.repository.BranchRepository;
import com.carebike.backend.features.auth.service.UserService;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;
import java.util.List;
import java.util.Set;
import java.util.stream.Collectors;
import java.util.Map;

@RestController
@RequestMapping("/api/users")
public class UserController {

    private final UserRepository userRepository;
    private final BranchRepository branchRepository;
    private final UserService userService;

    public UserController(UserRepository userRepository, BranchRepository branchRepository, UserService userService) {
        this.userRepository = userRepository;
        this.branchRepository = branchRepository;
        this.userService = userService;
    }

    /** GET /api/users — list all users */
    @GetMapping
    public ResponseEntity<List<User>> getAllUsers() {
        return ResponseEntity.ok(userRepository.findAll());
    }

    /** GET /api/users/{id} — get single user */
    @GetMapping("/{id}")
    public ResponseEntity<User> getUserById(@PathVariable Integer id) {
        return userRepository.findById(id)
                .map(ResponseEntity::ok)
                .orElse(ResponseEntity.notFound().build());
    }

    /** PUT /api/users/{id} */
    @PutMapping("/{id}")
    public ResponseEntity<?> updateUserProfile(@PathVariable Integer id, @RequestBody Map<String, String> request) {
        try {
            User user = userRepository.findById(id)
                    .orElseThrow(() -> new RuntimeException("Không tìm thấy người dùng trong hệ thống."));

            // Cập nhật tên
            if (request.containsKey("fullName")) {
                user.setFullName(request.get("fullName"));
            }
            
            if (request.containsKey("phone") && request.get("phone") != null) {
                String phone = request.get("phone").trim();
                if (!phone.matches("^[0-9]{10,}$")) {
                    throw new RuntimeException("Số điện thoại không hợp lệ (Phải là số và ít nhất 10 chữ số).");
                }
                user.setPhone(phone);
            }
            
            // Cập nhật ngày sinh
            if (request.containsKey("dob") && request.get("dob") != null && !request.get("dob").isBlank()) {
                LocalDate dob = LocalDate.parse(request.get("dob"));
                
                // Ngày hiện tại trừ đi 18 năm. Nếu ngày sinh nằm sau mốc này -> Chưa đủ 18
                if (LocalDate.now().minusYears(18).isBefore(dob)) {
                    throw new RuntimeException("Bạn phải từ đủ 18 tuổi trở lên để sử dụng dịch vụ.");
                }
                user.setDob(dob);
            }

            // Cập nhật giới tính
            if (request.containsKey("gender")) {
                user.setGender(request.get("gender"));
            }

            userRepository.save(user);
            return ResponseEntity.ok(Map.of("message", "Cập nhật thông tin thành công!"));
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(Map.of("message", "Lỗi cập nhật: " + e.getMessage()));
        }
    }

    /** PUT /api/users/{id}/toggle-status — lock or unlock a customer account */
    @PutMapping("/{id}/toggle-status")
    public ResponseEntity<?> toggleStatus(@PathVariable Integer id) {
        return userRepository.findById(id)
                .map(user -> {
                    boolean currentlyActive = user.getIsActive() != null ? user.getIsActive() : true;
                    user.setIsActive(!currentlyActive);
                    userRepository.save(user);
                    return ResponseEntity.ok(user);
                })
                .orElse(ResponseEntity.notFound().build());
    }

    @GetMapping("/available-managers")
    public ResponseEntity<List<User>> getAvailableManagers(
            @RequestParam(name = "currentBranchId", required = false) Integer currentBranchId) {

        // All users with BRANCH role
        List<User> allBranchUsers = userRepository.findByRoleRoleName("BRANCH");

        if (currentBranchId == null) {
            // No branch context — return all idle managers (none assigned anywhere)
            Set<Integer> allAssigned = branchRepository.findAll()
                    .stream()
                    .filter(b -> b.getManager() != null)
                    .map(b -> b.getManager().getId())
                    .collect(Collectors.toSet());

            List<User> idle = allBranchUsers.stream()
                    .filter(u -> !allAssigned.contains(u.getId()))
                    .collect(Collectors.toList());
            return ResponseEntity.ok(idle);
        }

        // IDs of managers assigned to OTHER branches (not the current one)
        Set<Integer> busyElsewhere = Set.copyOf(
                branchRepository.findManagerIdsAssignedToOtherBranches(currentBranchId)
        );

        // Keep: idle users + the current branch's own manager
        List<User> available = allBranchUsers.stream()
                .filter(u -> !busyElsewhere.contains(u.getId()))
                .collect(Collectors.toList());

        return ResponseEntity.ok(available);
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<?> deleteUser(@PathVariable Integer id) {
        try {
            userService.deleteStaffAccount(id);
            return ResponseEntity.ok(Map.of("message", "Đã xóa vĩnh viễn tài khoản thành công!"));
        } catch (RuntimeException e) {
            // Trả về thông báo lỗi chặn phân công chéo (400 Bad Request)
            return ResponseEntity.badRequest().body(Map.of("message", e.getMessage()));
        } catch (Exception e) {
            return ResponseEntity.status(500).body(Map.of("message", "Lỗi máy chủ: " + e.getMessage()));
        }
    }
}