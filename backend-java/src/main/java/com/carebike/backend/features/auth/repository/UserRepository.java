package com.carebike.backend.features.auth.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import com.carebike.backend.features.auth.entity.User;

import java.util.List;
import java.util.Optional;

@Repository
public interface UserRepository extends JpaRepository<User, Integer> {
    
    // Tìm user bằng mã UID của Firebase
    Optional<User> findByFirebaseUid(String firebaseUid);
    
    // Tìm user bằng Email
    Optional<User> findByEmail(String email);
    
    // Kiểm tra tồn tại
    boolean existsByEmail(String email);
    boolean existsByFirebaseUid(String firebaseUid);

    /** Tìm tất cả user theo nhóm quyền ("BRANCH", "CUSTOMER") */
    List<User> findByRoleRoleName(String roleName);
}