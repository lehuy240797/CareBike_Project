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
    @Autowired
    private com.carebike.backend.features.websocket.service.WebSocketEventService webSocketEventService;

    @Autowired
    private com.carebike.backend.features.branch.repository.BranchRepository branchRepository;

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

    /** Kiểm tra nhân viên có đang trong ca trực hiện tại không */
    @GetMapping("/verify-shift")
    public ResponseEntity<?> verifyShift(@RequestParam String code) {
        return staffRepository.findByStaffCode(code.toUpperCase().trim()).map(staff -> {
            java.time.LocalDateTime now = java.time.LocalDateTime.now();
            java.time.LocalDate date = now.toLocalDate();
            int hour = now.getHour();
            String currentShift = "NIGHT";
            
            if (hour >= 6 && hour < 14) {
                currentShift = "MORNING";
            } else if (hour >= 14 && hour < 22) {
                currentShift = "AFTERNOON";
            } else {
                currentShift = "NIGHT";
                if (hour < 6) {
                    date = date.minusDays(1);
                }
            }

            boolean isOnShift = shiftRepository.existsByStaffIdAndShiftDateAndShiftType(staff.getId(), date, currentShift);
            if (!isOnShift) {
                return ResponseEntity.badRequest().body(Map.of("message", "Nhân viên không có lịch trực trong ca hiện tại (" + currentShift + ")."));
            }
            return ResponseEntity.ok((Object) staff);
        }).orElse(ResponseEntity.status(404).body(Map.of("message", "Không tìm thấy nhân viên với mã này.")));
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

        // Validate max 2 shifts per day for a staff
        Map<String, Integer> staffDayShiftCount = new java.util.HashMap<>();
        for (Map<String, Object> item : shiftsData) {
            Integer staffId = (Integer) item.get("staffId");
            String shiftDateStr = (String) item.get("shiftDate");
            String key = staffId + "_" + shiftDateStr;
            int count = staffDayShiftCount.getOrDefault(key, 0) + 1;
            if (count > 2) {
                throw new RuntimeException("Lỗi: Mỗi nhân viên không được làm quá 2 ca một ngày.");
            }
            staffDayShiftCount.put(key, count);
        }

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

    /** Tạo nhân viên mới cho chi nhánh */
    @PostMapping("/branch/{branchId}")
    public ResponseEntity<?> createStaff(@PathVariable Integer branchId, @RequestBody Staff staff) {
        var branch = branchRepository.findById(branchId)
                .orElseThrow(() -> new RuntimeException("Không tìm thấy chi nhánh"));
        staff.setBranch(branch);
        // Tự sinh mã nhân viên nếu chưa có
        if (staff.getStaffCode() == null || staff.getStaffCode().trim().isEmpty()) {
            long count = staffRepository.count();
            staff.setStaffCode(String.format("CBS-%04d", count + 1));
        }
        return ResponseEntity.ok(staffRepository.save(staff));
    }

    /** Cập nhật thông tin nhân viên */
    @PutMapping("/{id}")
    public ResponseEntity<?> updateStaff(@PathVariable Integer id, @RequestBody Staff staffDetails) {
        Staff staff = staffRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Không tìm thấy nhân viên"));
        staff.setFullName(staffDetails.getFullName());
        staff.setPhone(staffDetails.getPhone());
        if (staffDetails.getStaffCode() != null && !staffDetails.getStaffCode().isEmpty()) {
            staff.setStaffCode(staffDetails.getStaffCode());
        }
        return ResponseEntity.ok(staffRepository.save(staff));
    }

    /** Update staff status. */
    @PutMapping("/{id}/status")
    public ResponseEntity<?> updateStaffStatus(@PathVariable Integer id, @RequestBody Map<String, String> body) {
        Staff staff = staffRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Staff not found"));
        String statusStr = body.get("status");
        if (statusStr != null) {
            staff.setStatus(com.carebike.backend.features.staff.entity.StaffStatus.valueOf(statusStr));
            staffRepository.save(staff);
            if (staff.getBranch() != null) {
                webSocketEventService.sendBranchUpdate(staff.getBranch().getId(), "STAFF_UPDATED");
                webSocketEventService.sendBranchUpdate(staff.getBranch().getId(), "SHIFT_UPDATED");
            }
        }
        return ResponseEntity.ok(Map.of("message", "Staff status updated successfully"));
    }

    /** Delete staff. */
    @DeleteMapping("/{id}")
    public ResponseEntity<?> deleteStaff(@PathVariable Integer id) {
        Staff staff = staffRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Không tìm thấy nhân viên"));
        staffRepository.delete(staff);
        return ResponseEntity.ok(Map.of("message", "Xóa nhân viên thành công"));
    }
}

