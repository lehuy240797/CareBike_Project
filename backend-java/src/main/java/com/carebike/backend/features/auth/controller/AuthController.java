package com.carebike.backend.features.auth.controller;
import com.carebike.backend.features.auth.dto.ChangePasswordRequest;
import com.carebike.backend.features.auth.dto.JwtResponse;
import com.carebike.backend.features.auth.dto.LoginRequest;
import com.carebike.backend.features.auth.dto.RegisterRequest;
import com.carebike.backend.features.auth.dto.TokenRefreshRequest;
import com.carebike.backend.features.auth.dto.TokenRefreshResponse;
import com.carebike.backend.features.auth.entity.RefreshToken;
import com.carebike.backend.features.auth.entity.Role;
import com.carebike.backend.features.auth.repository.RoleRepository;
import com.carebike.backend.features.auth.repository.UserRepository;
import com.carebike.backend.features.auth.service.RefreshTokenService;
import com.carebike.backend.features.branch.dto.BranchRegistrationRequest;
import com.carebike.backend.features.branch.entity.Branch;
import com.carebike.backend.features.branch.repository.BranchRepository;

import org.springframework.transaction.annotation.Transactional;

import com.carebike.backend.security.JwtTokenProvider;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.http.ResponseEntity;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.core.userdetails.User;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/auth")
public class AuthController {

    private final AuthenticationManager authenticationManager;
    private final UserRepository userRepository;
    private final RoleRepository roleRepository;
    private final PasswordEncoder passwordEncoder;
    private final JwtTokenProvider tokenProvider;
    private final RefreshTokenService refreshTokenService;
    private final BranchRepository branchRepository;

    public AuthController(AuthenticationManager authenticationManager, UserRepository userRepository,
            RoleRepository roleRepository, PasswordEncoder passwordEncoder,
            JwtTokenProvider tokenProvider, RefreshTokenService refreshTokenService,
            BranchRepository branchRepository) {
        this.authenticationManager = authenticationManager;
        this.userRepository = userRepository;
        this.roleRepository = roleRepository;
        this.passwordEncoder = passwordEncoder;
        this.tokenProvider = tokenProvider;
        this.refreshTokenService = refreshTokenService;
        this.branchRepository = branchRepository;
    }

    // 1. API Đăng nhập: Đã nâng cấp để trả về cả 2 Token
    @PostMapping("/login")
    public ResponseEntity<?> authenticateUser(@RequestBody LoginRequest loginRequest) {
        Authentication authentication = authenticationManager.authenticate(
                new UsernamePasswordAuthenticationToken(loginRequest.getUsername(), loginRequest.getPassword()));

        SecurityContextHolder.getContext().setAuthentication(authentication);

        // Tạo Access Token (sống 15 phút)
        String jwt = tokenProvider.generateToken(authentication);

        User userDetails = (User) authentication.getPrincipal();

        // Lấy ID của user từ database để tạo Refresh Token tương ứng
        com.carebike.backend.features.auth.entity.User userEntity = userRepository.findByUsername(userDetails.getUsername()).get();
        RefreshToken refreshToken = refreshTokenService.createRefreshToken(userEntity.getId()); // Tạo Refresh Token
                                                                                                // (sống 30 ngày)

        String role = userDetails.getAuthorities().stream()
                .map(item -> item.getAuthority().replace("ROLE_", "")).findFirst().orElse("");

        // Trả về cả Access Token và Refresh Token cho Frontend lưu giữ
        return ResponseEntity.ok(new JwtResponse(jwt, refreshToken.getToken(), userDetails.getUsername(), role));
    }

    // 2. API GIA HẠN TOKEN MỚI (TỰ ĐỘNG CHẠY NGẦM TRÊN APP MOBILE/WEB)
    @PostMapping("/refresh")
    public ResponseEntity<?> refreshToken(@RequestBody TokenRefreshRequest request) {
        String requestRefreshToken = request.getRefreshToken();

        return refreshTokenService.findByToken(requestRefreshToken)
                .map(refreshTokenService::verifyExpiration) // Kiểm tra xem token này hết hạn 30 ngày chưa
                .map(RefreshToken::getUser)
                .map(user -> {
                    // Nếu hợp lệ, cấp ngay một Access Token mới tinh (gia hạn thêm 15 phút hoạt
                    // động)
                    String accessToken = tokenProvider.generateTokenFromUsername(user.getUsername());
                    return ResponseEntity.ok(new TokenRefreshResponse(accessToken, requestRefreshToken));
                })
                .orElseThrow(() -> new RuntimeException("Lỗi: Refresh token không tồn tại trong hệ thống!"));
    }

    @PostMapping("/register")
    public ResponseEntity<?> registerCustomer(@RequestBody RegisterRequest registerRequest) {
        if (userRepository.existsByUsername(registerRequest.getUsername())) {
            return ResponseEntity.badRequest().body("Lỗi: Tên đăng nhập đã tồn tại!");
        }

        com.carebike.backend.features.auth.entity.User user = new com.carebike.backend.features.auth.entity.User();
        user.setUsername(registerRequest.getUsername());
        user.setPassword(passwordEncoder.encode(registerRequest.getPassword()));
        user.setEmail(registerRequest.getEmail());
        user.setFullName(registerRequest.getFullName());
        user.setPhone(registerRequest.getPhone());

        Role customerRole = roleRepository.findById(3)
                .orElseThrow(() -> new RuntimeException("Lỗi: Không tìm thấy vai trò CUSTOMER"));
        user.setRole(customerRole);

        userRepository.save(user);
        return ResponseEntity.ok("Đăng ký tài khoản Khách hàng thành công!");
    }

    @PostMapping("/register-branch")
    @PreAuthorize("hasRole('ADMIN')") // Chỉ Admin mới gọi được
    @Transactional // Đảm bảo tính toàn vẹn dữ liệu cho cả 2 bảng
    public ResponseEntity<?> registerBranch(@RequestBody BranchRegistrationRequest request) {
        
        // 1. Kiểm tra trùng tên tài khoản trong bảng USERS
        if (userRepository.existsByUsername(request.getUsername())) {
            return ResponseEntity.badRequest().body("Error: Username is already taken!");
        }

        // 2. Khởi tạo và nạp dữ liệu cho bảng USERS
        com.carebike.backend.features.auth.entity.User user = new com.carebike.backend.features.auth.entity.User();
        user.setUsername(request.getUsername());
        user.setPassword(passwordEncoder.encode(request.getPassword())); // Mã hóa mật khẩu
        user.setEmail(request.getEmail());
        user.setFullName(request.getFullName());
        user.setPhone(request.getUserPhone());

        // Liên kết quyền BRANCH (role_id = 2)
        Role branchRole = roleRepository.findById(2)
                .orElseThrow(() -> new RuntimeException("Error: Role BRANCH not found!"));
        user.setRole(branchRole);

        // Lưu user trước để lấy ID tự sinh
        com.carebike.backend.features.auth.entity.User savedUser = userRepository.save(user);


        // 3. Khởi tạo và nạp dữ liệu cho bảng BRANCHES
        Branch branch = new Branch();
        branch.setName(request.getBranchName());
        branch.setAddress(request.getBranchAddress());
        branch.setPhone(request.getBranchPhone());
        branch.setLatitude(request.getLatitude());
        branch.setLongitude(request.getLongitude());
        
        if (request.getBranchStatus() != null && !request.getBranchStatus().isEmpty()) {
            branch.setStatus(request.getBranchStatus());
        } else {
            branch.setStatus("ACTIVE");
        }

        // THIẾT LẬP LIÊN KẾT: Gán ID của tài khoản quản lý vừa tạo vào cột manager_id của Branch
        branch.setManager(savedUser);

        // Lưu chi nhánh vào DB
        branchRepository.save(branch);

        return ResponseEntity.ok("Branch and its manager account created and fully linked successfully!");
    }

    // API TỰ ĐỔI MẬT KHẨU CHO TÀI KHOẢN ĐANG ĐĂNG NHẬP
    @PutMapping("/change-password")
    public ResponseEntity<?> changePassword(@RequestBody ChangePasswordRequest request) {
        // 1. Lấy thông tin username của người đang thực hiện request từ Token bảo mật
        org.springframework.security.core.Authentication authentication = 
                org.springframework.security.core.context.SecurityContextHolder.getContext().getAuthentication();
        String currentUsername = authentication.getName();

        // 2. Tìm User trong Database
        com.carebike.backend.features.auth.entity.User user = userRepository.findByUsername(currentUsername)
                .orElseThrow(() -> new RuntimeException("Error: User not found!"));

        // 3. Kiểm tra mật khẩu cũ gửi lên có khớp với mật khẩu băm trong DB không
        if (!passwordEncoder.matches(request.getOldPassword(), user.getPassword())) {
            return ResponseEntity.badRequest().body("Error: Current password (old password) is incorrect!");
        }

        // 4. Nếu khớp, tiến hành băm mật khẩu mới và cập nhật vào DB
        user.setPassword(passwordEncoder.encode(request.getNewPassword()));
        userRepository.save(user);

        return ResponseEntity.ok("Password updated successfully!");
    }
}