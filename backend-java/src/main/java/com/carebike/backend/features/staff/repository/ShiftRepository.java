package com.carebike.backend.features.staff.repository;

import com.carebike.backend.features.staff.entity.Shift;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface ShiftRepository extends JpaRepository<Shift, Integer> {
    List<Shift> findByBranchId(Integer branchId);
    List<Shift> findByBranchIdAndShiftDateBetween(Integer branchId, java.time.LocalDate startDate, java.time.LocalDate endDate);
    void deleteByBranchId(Integer branchId);
    void deleteByBranchIdAndShiftDateBetween(Integer branchId, java.time.LocalDate startDate, java.time.LocalDate endDate);
}
