package com.carebike.backend.features.rescue.controller;

import com.carebike.backend.features.rescue.dto.RescueRequestDto;
import com.carebike.backend.features.rescue.entity.Rescue;
import com.carebike.backend.features.rescue.repository.RescueRepository;
import com.carebike.backend.features.rescue.service.RescueService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/rescues")
@CrossOrigin(origins = "*")
public class RescueController {

    @Autowired
    private RescueService rescueService;

    @Autowired
    private RescueRepository rescueRepository;

    @PostMapping
    public ResponseEntity<?> requestRescue(@RequestBody RescueRequestDto dto) {
        Rescue savedRescue = rescueService.createRescueRequest(dto);
        return ResponseEntity.ok(savedRescue);
    }

    @GetMapping("/branch/{branchId}")
    public ResponseEntity<?> getRescuesByBranch(@PathVariable Integer branchId) {
        List<Rescue> list = rescueService.getRescuesByBranch(branchId);
        return ResponseEntity.ok(list);
    }

    @PutMapping("/{id}/accept")
    public ResponseEntity<?> acceptRescue(@PathVariable Long id) {
        Rescue rescue = rescueService.acceptRescue(id);
        return ResponseEntity.ok(rescue);
    }

    @GetMapping("/{id}/verify-staff")
    public ResponseEntity<?> verifyAssignedStaff(
            @PathVariable Long id, @RequestParam String code) {
        return ResponseEntity.ok(rescueService.verifyAssignedStaff(id, code));
    }

    @GetMapping("/{id}/assigned-staff")
    public ResponseEntity<?> getAssignedStaff(@PathVariable Long id) {
        return ResponseEntity.ok(rescueService.getAssignedStaff(id));
    }


    @PostMapping("/{id}/complete")
    public ResponseEntity<?> completeRescue(
            @PathVariable Long id,
            @RequestBody com.carebike.backend.features.rescue.dto.RescueCompleteRequest request) {
        rescueService.completeRescue(id, request);
        return ResponseEntity.ok(java.util.Map.of(
                "message", "Payment confirmed and rescue completed successfully.")); /*
        return ResponseEntity.ok().body("{\"message\": \"Xác nhận thanh toán và lưu lịch sử thành công\"}");
        */
    }

    @GetMapping("/debug")
    public ResponseEntity<?> debugRescues() {
        return ResponseEntity.ok(rescueRepository.findAll());
    }
}
