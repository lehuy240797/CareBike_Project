package com.carebike.backend.features.staff.repository;

import com.carebike.backend.features.staff.entity.Staff;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface StaffRepository extends JpaRepository<Staff, Integer> {
    List<Staff> findByBranchId(Integer branchId);
    Optional<Staff> findByStaffCode(String staffCode);
    boolean existsByStaffCode(String staffCode);
}
