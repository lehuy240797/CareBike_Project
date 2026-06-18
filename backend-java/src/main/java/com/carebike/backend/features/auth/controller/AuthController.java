package com.carebike.backend.features.auth.controller;

import com.google.firebase.auth.FirebaseToken;
import com.carebike.backend.features.auth.dto.RegisterRequest;
import com.carebike.backend.features.branch.dto.BranchRegistrationRequest;
import com.carebike.backend.features.auth.entity.User;
import com.carebike.backend.features.auth.entity.Role;
import com.carebike.backend.features.auth.repository.UserRepository;
import com.carebike.backend.features.auth.repository.RoleRepository;
import com.carebike.backend.features.auth.service.UserService;
import com.carebike.backend.features.branch.repository.BranchRepository;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.bind.annotation.*;

import java.util.HashMap;
import java.util.Map;

@RestController
@RequestMapping("/api/auth")
public class AuthController {

    private final UserService userService;
    private final UserRepository userRepository;
    private final RoleRepository roleRepository;
    private final BranchRepository branchRepository;
    public AuthController(UserService userService, UserRepository userRepository, RoleRepository roleRepository, BranchRepository branchRepository) {
        this.userService = userService;
        this.userRepository = userRepository;
        this.roleRepository = roleRepository;
        this.branchRepository = branchRepository;
    }

    /**
     * POST /api/auth/register
     */
    @PostMapping("/register")
    public ResponseEntity<?> registerCustomer(@RequestBody RegisterRequest registerRequest, HttpServletRequest request) {
        try {
            String firebaseUid = (String) request.getAttribute("firebaseUid");
            if (firebaseUid == null || firebaseUid.isBlank()) {
                return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                        .body(Map.of("message", "Yêu cầu không hợp lệ. Không tìm thấy mã xác thực từ Firebase Token."));
            }

            if (userRepository.existsByEmail(registerRequest.getEmail())) {
                return ResponseEntity.badRequest().body(Map.of("message", "Email này đã được sử dụng trong hệ thống CareBike."));
            }

            Role customerRole = roleRepository.findByRoleName("CUSTOMER")
                    .orElseThrow(() -> new RuntimeException("Lỗi cấu hình hệ thống: Không tìm thấy vai trò CUSTOMER."));

            User customer = new User();
            customer.setFirebaseUid(firebaseUid);
            customer.setEmail(registerRequest.getEmail());
            customer.setFullName(registerRequest.getFullName());
            customer.setPhone(registerRequest.getPhone());
            customer.setRole(customerRole);
            customer.setIsActive(true);

            userRepository.save(customer);

            return ResponseEntity.ok(Map.of("message", "Đăng ký tài khoản thành công!"));
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(Map.of("message", "Lỗi: " + e.getMessage()));
        }
    }

    /**
     * POST /api/auth/login
     */
    @PostMapping("/login")
    public ResponseEntity<?> login(HttpServletRequest request) {
        try {
            FirebaseToken decodedToken = (FirebaseToken) request.getAttribute("firebaseToken");
            
            if (decodedToken == null) {
                return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                        .body(Map.of("message", "Token không hợp lệ hoặc không có quyền truy cập."));
            }

            User user = userService.login(decodedToken);
            
            String clientType = request.getHeader("X-Client-Type");
            String roleName = user.getRole() != null ? user.getRole().getRoleName() : "";
            
            if ("MOBILE".equalsIgnoreCase(clientType)) {
                if ("ADMIN".equalsIgnoreCase(roleName)) {
                    return ResponseEntity.status(HttpStatus.FORBIDDEN)
                            .body(Map.of("message", "Tài khoản quản trị không được phép đăng nhập trên ứng dụng di động. Vui lòng sử dụng Web Dashboard."));
                }
            } else {
                if ("CUSTOMER".equalsIgnoreCase(roleName)) {
                    return ResponseEntity.status(HttpStatus.FORBIDDEN)
                            .body(Map.of("message", "Tài khoản khách hàng chỉ được phép sử dụng trên thiết bị di động. Vui lòng tải ứng dụng CareBike để tiếp tục."));
                }
            }

            if (user.getIsActive() != null && !user.getIsActive()) {
                return ResponseEntity.status(HttpStatus.FORBIDDEN)
                        .body(Map.of("message", "Tài khoản của bạn đã bị khóa. Vui lòng liên hệ Admin."));
            }

            Map<String, Object> responseData = new HashMap<>();
            responseData.put("userId", user.getId());
            responseData.put("email", user.getEmail());
            responseData.put("fullName", user.getFullName() != null ? user.getFullName() : "");
            responseData.put("role", roleName);
            responseData.put("phone", user.getPhone() != null ? user.getPhone() : "");
            responseData.put("dob", user.getDob() != null ? user.getDob().toString() : "");
            responseData.put("gender", user.getGender() != null ? user.getGender() : "");

            if ("BRANCH".equalsIgnoreCase(roleName)) {
                branchRepository.findByManagerId(user.getId()).ifPresent(branch -> {
                    responseData.put("branchId", branch.getId());
                });
            }

            return ResponseEntity.ok(responseData);
            
        } catch (RuntimeException e) {
            return ResponseEntity.badRequest().body(Map.of("message", e.getMessage()));
        } catch (Exception e) {
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(Map.of("message", "Lỗi hệ thống: " + e.getMessage()));
        }
    }

    /**
     * POST /api/auth/create-staff
     */
    @PostMapping("/create-staff")
    public ResponseEntity<?> createStaffAccount(@RequestBody BranchRegistrationRequest request) {
        try {
            User createdUser = userService.createStaffAccount(request);
            return ResponseEntity.ok(Map.of(
                    "message", "Tạo tài khoản nhân sự quản lý chi nhánh thành công!",
                    "userId", createdUser.getId()
            ));
        } catch (RuntimeException e) {
            return ResponseEntity.badRequest().body(Map.of("message", e.getMessage()));
        } catch (Exception e) {
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(Map.of("message", "Lỗi máy chủ: " + e.getMessage()));
        }
    }

    /**
     * GET /api/auth/me
     */
    @GetMapping("/me")
    public ResponseEntity<?> getCurrentUser() {
        try {
            Object principal = SecurityContextHolder.getContext().getAuthentication().getPrincipal();
            
            if (principal instanceof User) {
                User loggedInUser = (User) principal;
                String roleName = loggedInUser.getRole() != null ? loggedInUser.getRole().getRoleName() : "";
                
                Map<String, Object> responseData = new HashMap<>();
                responseData.put("userId", loggedInUser.getId());
                responseData.put("email", loggedInUser.getEmail());
                responseData.put("fullName", loggedInUser.getFullName() != null ? loggedInUser.getFullName() : "");
                responseData.put("role", roleName);
                responseData.put("phone", loggedInUser.getPhone() != null ? loggedInUser.getPhone() : "");
                responseData.put("dob", loggedInUser.getDob() != null ? loggedInUser.getDob().toString() : "");
                responseData.put("gender", loggedInUser.getGender() != null ? loggedInUser.getGender() : "");

                if ("BRANCH".equalsIgnoreCase(roleName)) {
                    branchRepository.findByManagerId(loggedInUser.getId()).ifPresent(branch -> {
                        responseData.put("branchId", branch.getId());
                    });
                }

                return ResponseEntity.ok(responseData);
            }
            
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body(Map.of("message", "Tài khoản chưa thực hiện đăng nhập."));
        } catch (Exception e) {
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(Map.of("message", "Không thể truy xuất thông tin phiên làm việc: " + e.getMessage()));
        }
    }
}