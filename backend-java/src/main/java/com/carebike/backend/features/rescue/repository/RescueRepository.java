package com.carebike.backend.features.rescue.repository;

import com.carebike.backend.features.rescue.entity.Rescue;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.time.LocalDateTime;

@Repository
public interface RescueRepository extends JpaRepository<Rescue, Long> {
    // Lấy các ca cứu hộ của 1 chi nhánh (Dùng cho React Admin)
    List<Rescue> findByBranchIdOrderByCreatedAtDesc(Integer branchId);
    
    // Lấy lịch sử cứu hộ của 1 khách hàng (Dùng cho Flutter)
    List<Rescue> findByCustomerIdOrderByCreatedAtDesc(Integer customerId);

    long countByStaffCodeIgnoreCaseAndStatusInAndCreatedAtGreaterThanEqualAndCreatedAtLessThan(
            String staffCode,
            List<String> statuses,
            LocalDateTime shiftStart,
            LocalDateTime shiftEnd);
}