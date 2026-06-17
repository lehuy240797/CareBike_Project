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

    // API 1: Dành cho App Flutter gửi yêu cầu cứu hộ
    @PostMapping
    public ResponseEntity<?> requestRescue(@RequestBody RescueRequestDto dto) {
        try {
            Rescue savedRescue = rescueService.createRescueRequest(dto);
            return ResponseEntity.ok(savedRescue);
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(e.getMessage());
        }
    }

    // API 2: Dành cho React Admin lấy danh sách ca cứu hộ của chi nhánh mình
    @GetMapping("/branch/{branchId}")
    public ResponseEntity<?> getRescuesByBranch(@PathVariable Long branchId) {
        try {
            List<Rescue> list = rescueService.getRescuesByBranch(branchId);
            return ResponseEntity.ok(list);
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(e.getMessage());
        }
    }

    // Update rescue status
    @PutMapping("/{id}/accept")
    public ResponseEntity<?> acceptRescue(@PathVariable Long id) {
        try {
            Rescue rescue = rescueRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Không tìm thấy ca cứu hộ"));
            
            rescue.setStatus("ACCEPTED"); // Đổi trạng thái sang Đã nhận
            return ResponseEntity.ok(rescueRepository.save(rescue));
        } catch (Exception e) {
            return ResponseEntity.badRequest().body("Lỗi: " + e.getMessage());
        }
    }
}