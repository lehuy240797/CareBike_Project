package com.carebike.backend.features.staff.repository;

import com.carebike.backend.features.staff.entity.Shift;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface ShiftRepository extends JpaRepository<Shift, Integer> {
    List<Shift> findByBranchId(Integer branchId);
    List<Shift> findByBranchIdAndShiftDateBetween(Integer branchId, java.time.LocalDate startDate, java.time.LocalDate endDate);
    List<Shift> findByStaffIdAndShiftDate(Integer staffId, java.time.LocalDate shiftDate);
    boolean existsByStaffIdAndShiftDateAndShiftType(Integer staffId, java.time.LocalDate shiftDate, String shiftType);
    void deleteByBranchId(Integer branchId);
    void deleteByBranchIdAndShiftDateBetween(Integer branchId, java.time.LocalDate startDate, java.time.LocalDate endDate);

    @org.springframework.data.jpa.repository.Lock(jakarta.persistence.LockModeType.PESSIMISTIC_WRITE)
    @org.springframework.data.jpa.repository.Query("SELECT s.staff FROM Shift s WHERE s.branch.id = :branchId AND s.shiftDate = :date AND s.shiftType = :type AND (s.staff.status = com.carebike.backend.features.staff.entity.StaffStatus.FREE OR s.staff.status IS NULL) ORDER BY s.staff.id ASC")
    List<com.carebike.backend.features.staff.entity.Staff> findFreeStaffInShift(
        @org.springframework.data.repository.query.Param("branchId") Integer branchId, 
        @org.springframework.data.repository.query.Param("date") java.time.LocalDate date, 
        @org.springframework.data.repository.query.Param("type") String type);

    @org.springframework.data.jpa.repository.Lock(jakarta.persistence.LockModeType.PESSIMISTIC_WRITE)
    @org.springframework.data.jpa.repository.Query("SELECT s.staff FROM Shift s WHERE s.branch.id = :branchId AND s.shiftDate = :date AND s.shiftType = :type ORDER BY s.staff.id ASC")
    List<com.carebike.backend.features.staff.entity.Staff> findStaffInShift(
        @org.springframework.data.repository.query.Param("branchId") Integer branchId,
        @org.springframework.data.repository.query.Param("date") java.time.LocalDate date,
        @org.springframework.data.repository.query.Param("type") String type);
}
