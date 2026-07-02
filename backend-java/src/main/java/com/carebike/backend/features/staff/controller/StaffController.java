package com.carebike.backend.features.staff.controller;

import com.carebike.backend.features.staff.entity.Staff;
import com.carebike.backend.features.staff.entity.Shift;
import com.carebike.backend.features.staff.repository.StaffRepository;
import com.carebike.backend.features.staff.repository.ShiftRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;
import java.time.LocalDate;
import org.springframework.format.annotation.DateTimeFormat;

@RestController
@RequestMapping("/api/staff")
@CrossOrigin(origins = "*")
public class StaffController {

    @Autowired
    private StaffRepository staffRepository;

    @Autowired
    private ShiftRepository shiftRepository;

    /** Lấy danh sách nhân viên theo chi nhánh */
    @GetMapping("/branch/{branchId}")
    public ResponseEntity<List<Staff>> getStaffByBranch(@PathVariable Integer branchId) {
        return ResponseEntity.ok(staffRepository.findByBranchId(branchId));
    }

    /** Tìm nhân viên theo mã nhân viên (CBS-xxxx) */
    @GetMapping("/lookup")
    public ResponseEntity<?> lookupByCode(@RequestParam String code) {
        return staffRepository.findByStaffCode(code.toUpperCase().trim())
                .map(s -> ResponseEntity.ok((Object) s))
                .orElse(ResponseEntity.notFound().build());
    }

    /** Lấy lịch phân ca theo chi nhánh theo tuần */
    @GetMapping("/shifts/branch/{branchId}")
    public ResponseEntity<List<Shift>> getShiftsByBranch(
            @PathVariable Integer branchId,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate startDate,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate endDate) {
        
        if (startDate != null && endDate != null) {
            return ResponseEntity.ok(shiftRepository.findByBranchIdAndShiftDateBetween(branchId, startDate, endDate));
        }
        return ResponseEntity.ok(shiftRepository.findByBranchId(branchId));
    }

    /** Cập nhật toàn bộ lịch phân ca cho chi nhánh trong tuần */
    @PutMapping("/shifts/branch/{branchId}")
    @Transactional
    public ResponseEntity<?> updateShifts(
            @PathVariable Integer branchId,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate startDate,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate endDate,
            @RequestBody List<Map<String, Object>> shiftsData) {

        // Xóa tất cả ca cũ của chi nhánh trong khoảng ngày này
        shiftRepository.deleteByBranchIdAndShiftDateBetween(branchId, startDate, endDate);

        // Tạo lại ca mới từ dữ liệu gửi lên
        var branch = new com.carebike.backend.features.branch.entity.Branch();
        branch.setId(branchId);

        for (Map<String, Object> item : shiftsData) {
            Integer staffId = (Integer) item.get("staffId");
            String shiftDateStr = (String) item.get("shiftDate");
            LocalDate shiftDate = LocalDate.parse(shiftDateStr);
            String shiftType = (String) item.get("shiftType");

            Staff staff = staffRepository.findById(staffId)
                    .orElseThrow(() -> new RuntimeException("Không tìm thấy nhân viên ID: " + staffId));

            Shift shift = Shift.builder()
                    .staff(staff)
                    .shiftDate(shiftDate)
                    .shiftType(shiftType)
                    .branch(branch)
                    .build();
            shiftRepository.save(shift);
        }

        return ResponseEntity.ok(Map.of("message", "Cập nhật ca làm việc thành công"));
    }
}
