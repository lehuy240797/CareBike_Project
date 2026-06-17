package com.carebike.backend.features.auth.service;

import java.util.Map;
import com.carebike.backend.features.branch.dto.BranchRegistrationRequest;
import com.carebike.backend.features.auth.entity.Role;
import com.carebike.backend.features.auth.entity.User;
import com.carebike.backend.features.auth.repository.RoleRepository;
import com.carebike.backend.features.auth.repository.UserRepository;
import com.google.firebase.auth.FirebaseAuth;
import com.google.firebase.auth.FirebaseToken;
import com.google.firebase.auth.UserRecord;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import com.carebike.backend.features.branch.repository.BranchRepository;

@Service
public class UserService {

    private final UserRepository userRepository;
    private final RoleRepository roleRepository;
    private final BranchRepository branchRepository;

    public UserService(UserRepository userRepository, RoleRepository roleRepository, BranchRepository branchRepository) {
        this.userRepository = userRepository;
        this.roleRepository = roleRepository;
        this.branchRepository = branchRepository;
    }

    /**
     * Logic Đăng nhập / Đăng ký tự động
     */
    @Transactional
    public User login(FirebaseToken decodedToken) {
        String firebaseUid = decodedToken.getUid();

        // Tìm user trong Database theo firebaseUid
        return userRepository.findByFirebaseUid(firebaseUid).orElseGet(() -> {
            
            // 1. KIỂM TRA XEM ĐÂY LÀ ĐĂNG NHẬP BẰNG GOOGLE HAY EMAIL/PASSWORD
            Object firebaseClaim = decodedToken.getClaims().get("firebase");
            String signInProvider = "";

            // Ép kiểu an toàn (Safe Casting) để xóa hoàn toàn cảnh báo vàng
            if (firebaseClaim instanceof Map<?, ?>) {
                Map<?, ?> firebaseInfo = (Map<?, ?>) firebaseClaim;
                Object providerObj = firebaseInfo.get("sign_in_provider");
                if (providerObj != null) {
                    signInProvider = providerObj.toString();
                }
            }

            // NẾU LÀ FORM TRUYỀN THỐNG -> TỪ CHỐI TỰ ĐỘNG TẠO 
            // (Để nhường quyền cho luồng API /register xử lý)
            if (!"google.com".equals(signInProvider)) {
                throw new RuntimeException("Tài khoản chưa được đăng ký hoàn tất trong hệ thống.");
            }

            // ==============================================
            // NẾU LÀ GOOGLE -> TỰ ĐỘNG TẠO TÀI KHOẢN MỚI
            // ==============================================
            Role customerRole = roleRepository.findByRoleName("CUSTOMER")
                    .orElseThrow(() -> new RuntimeException("Lỗi hệ thống: Không tìm thấy vai trò CUSTOMER."));

            User newUser = new User();
            newUser.setFirebaseUid(firebaseUid);

            String email = decodedToken.getEmail();
            String name = decodedToken.getName();

            newUser.setEmail(email != null ? email : firebaseUid + "@no-email.com");
            newUser.setFullName(name != null && !name.isEmpty() ? name : "Khách hàng CareBike");
            
            newUser.setRole(customerRole);
            newUser.setIsActive(true);

            return userRepository.save(newUser);
        });
    }

    /**
     * Logic tạo tài khoản nhân sự và đồng bộ Firebase + MySQL
     */
    @Transactional
    public User createStaffAccount(BranchRegistrationRequest request) throws Exception {
        // 1. Kiểm tra Email tồn tại chưa
        if (userRepository.existsByEmail(request.getEmail())) {
            throw new RuntimeException("Email '" + request.getEmail() + "' đã được sử dụng.");
        }

        // 2. Tạo User trên Firebase
        UserRecord.CreateRequest firebaseRequest = new UserRecord.CreateRequest()
                .setEmail(request.getEmail())
                .setPassword(request.getPassword())
                .setDisplayName(request.getFullName() != null ? request.getFullName() : "Admin Chi Nhánh");
        
        UserRecord firebaseUser = FirebaseAuth.getInstance().createUser(firebaseRequest);

        // 3. Lấy Role BRANCH trong hệ thống
        Role branchRole = roleRepository.findByRoleName("BRANCH")
                .orElseThrow(() -> new RuntimeException("Lỗi hệ thống: Không tìm thấy vai trò BRANCH."));

        // 4. Lưu thông tin xuống MySQL
        User newUser = new User();
        newUser.setFirebaseUid(firebaseUser.getUid());
        newUser.setEmail(request.getEmail());
        newUser.setFullName(request.getFullName());
        newUser.setPhone(request.getUserPhone());
        newUser.setRole(branchRole);
        newUser.setIsActive(true);

        return userRepository.save(newUser);
    }

    // Logic xóa tài khoản nhân sự (đồng bộ Firebase + MySQL)
    @Transactional(rollbackFor = Exception.class)
    public void deleteStaffAccount(Integer id) throws Exception {
        // 1. Tìm user trong DB
        User user = userRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Không tìm thấy tài khoản để xóa."));

        // 2. RÀNG BUỘC AN TOÀN: Kiểm tra xem tài khoản này có đang quản lý chi nhánh nào không
        boolean isManaging = branchRepository.findByManagerId(id).isPresent();
        if (isManaging) {
            throw new RuntimeException("Không thể xóa! Tài khoản này đang được phân công quản lý một chi nhánh.");
        }

        // 3. Xóa trên Cloud Firebase trước
        if (user.getFirebaseUid() != null && !user.getFirebaseUid().isBlank()) {
            try {
                FirebaseAuth.getInstance().deleteUser(user.getFirebaseUid());
            } catch (Exception e) {
                if (!e.getMessage().contains("user-not-found")) {
                    throw new RuntimeException("Lỗi khi xóa tài khoản trên Firebase: " + e.getMessage());
                }
            }
        }

        // 4. Xóa dưới cơ sở dữ liệu MySQL
        userRepository.delete(user);
    }
}