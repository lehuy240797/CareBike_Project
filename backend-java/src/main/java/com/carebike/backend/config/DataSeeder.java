package com.carebike.backend.config;

import com.carebike.backend.features.auth.entity.Role;
import com.carebike.backend.features.auth.entity.User;
import com.carebike.backend.features.auth.repository.RoleRepository;
import com.carebike.backend.features.auth.repository.UserRepository;
import org.springframework.boot.CommandLineRunner;
import org.springframework.stereotype.Component;

@Component
public class DataSeeder implements CommandLineRunner {

    private final UserRepository userRepository;
    private final RoleRepository roleRepository;

    public DataSeeder(UserRepository userRepository, RoleRepository roleRepository) {
        this.userRepository = userRepository;
        this.roleRepository = roleRepository;
    }

    @Override
    public void run(String... args) throws Exception {
        // 1. TỰ ĐỘNG TẠO 3 QUYỀN (ROLES) NẾU BẢNG ROLES TRỐNG
        if (roleRepository.count() == 0) {
            Role adminRole = new Role(); adminRole.setRoleName("ADMIN"); roleRepository.save(adminRole);
            Role branchRole = new Role(); branchRole.setRoleName("BRANCH"); roleRepository.save(branchRole);
            Role customerRole = new Role(); customerRole.setRoleName("CUSTOMER"); roleRepository.save(customerRole);
            System.out.println("✅ Đã khởi tạo 3 Roles mặc định vào Database.");
        }

        // 2. TỰ ĐỘNG TẠO TÀI KHOẢN SUPER ADMIN
        String adminEmail = "admin@carebike.com";
        if (!userRepository.existsByEmail(adminEmail)) {
            User admin = new User();
            admin.setEmail(adminEmail);
            admin.setFullName("Super Admin CareBike");
            admin.setFirebaseUid("UnmBZJtdaWUsE3UcZ1QrDYBtYXp1"); 
            
            // Gán quyền ADMIN (Role ID = 1)
            Role adminRole = roleRepository.findById(1).orElseThrow();
            admin.setRole(adminRole);
            
            userRepository.save(admin);
            System.out.println("Đã khởi tạo tài khoản Super Admin thành công!");
        }

    }
}