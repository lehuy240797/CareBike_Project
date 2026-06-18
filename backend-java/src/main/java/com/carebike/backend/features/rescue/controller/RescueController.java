package com.carebike.backend.features.rescue.controller;

import com.carebike.backend.features.rescue.dto.RescueRequestDto;
import com.carebike.backend.features.rescue.entity.Rescue;
import com.carebike.backend.features.rescue.service.RescueService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import com.carebike.backend.features.rescue.repository.RescueRepository;

import java.util.List;

@RestController
@RequestMapping("/api/rescues")
@CrossOrigin(origins = "*")
public class RescueController {

    @Autowired
    private RescueService rescueService;

    @Autowired
    private RescueRepository rescueRepository;

    /**
     * POST /api/rescues
     * API xử lý yêu cầu tạo ca cứu hộ mới từ ứng dụng di động.
     * Các lỗi validation sẽ được xử lý tập trung thông qua GlobalExceptionHandler.
     */
    @PostMapping
    public ResponseEntity<?> requestRescue(@RequestBody RescueRequestDto dto) {
        Rescue savedRescue = rescueService.createRescueRequest(dto);
        return ResponseEntity.ok(savedRescue);
    }

    /**
     * GET /api/rescues/branch/{branchId}
     * API truy xuất danh sách các ca cứu hộ thuộc về một chi nhánh cụ thể.
     * Ghi chú: Cần bổ sung cơ chế phân trang (Pagination) để tối ưu hiệu suất truy vấn.
     */
    @GetMapping("/branch/{branchId}")
    public ResponseEntity<?> getRescuesByBranch(@PathVariable Long branchId) {
        List<Rescue> list = rescueService.getRescuesByBranch(branchId);
        return ResponseEntity.ok(list);
    }

    /**
     * PUT /api/rescues/{id}/accept
     * API cập nhật trạng thái ca cứu hộ khi chi nhánh xác nhận tiếp nhận.
     */
    @PutMapping("/{id}/accept")
    public ResponseEntity<?> acceptRescue(@PathVariable Long id) {
        Rescue rescue = rescueRepository.findById(id)
            .orElseThrow(() -> new RuntimeException("Không tìm thấy ca cứu hộ"));
        
        rescue.setStatus("ACCEPTED"); // Đổi trạng thái sang Đã nhận
        return ResponseEntity.ok(rescueRepository.save(rescue));
    }
}