package com.carebike.backend.features.rescue.service;

import com.carebike.backend.features.rescue.dto.RescueRequestDto;
import com.carebike.backend.features.rescue.entity.Rescue;
import com.carebike.backend.features.rescue.repository.RescueRepository;
import org.springframework.messaging.simp.SimpMessagingTemplate;

// Import các Repository khác
import com.carebike.backend.features.branch.entity.Branch;
import com.carebike.backend.features.branch.repository.BranchRepository;
import com.carebike.backend.features.auth.repository.UserRepository;
import com.carebike.backend.features.vehicle.repository.VehicleRepository;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Service
public class RescueService {

    @Autowired
    private RescueRepository rescueRepository;

    @Autowired
    private BranchRepository branchRepository;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private VehicleRepository vehicleRepository;
    
    @Autowired
    private SimpMessagingTemplate messagingTemplate;

    @Transactional
    public Rescue createRescueRequest(RescueRequestDto dto) {
        // 1. Lấy tất cả chi nhánh
        List<Branch> allBranches = branchRepository.findAll(); 
        
        if (allBranches.isEmpty()) {
            throw new RuntimeException("Hiện không có chi nhánh nào hoạt động.");
        }

        Branch nearestBranch = null;
        double minDistance = Double.MAX_VALUE;

        // 2. Quét tìm chi nhánh gần nhất
        for (Branch branch : allBranches) {
            if (branch.getLatitude() != null && branch.getLongitude() != null) {
                // FIX LỖI 1: Ép kiểu BigDecimal của Branch về double bằng .doubleValue()
                // Ép kiểu luôn cho dto đề phòng dto cũng đang bị sai kiểu
                double distance = calculateHaversine(
                        dto.getLatitude().doubleValue(), 
                        dto.getLongitude().doubleValue(), 
                        branch.getLatitude().doubleValue(), 
                        branch.getLongitude().doubleValue()
                );
                
                if (distance < minDistance) {
                    minDistance = distance;
                    nearestBranch = branch;
                }
            }
        }

        if (nearestBranch == null) {
            throw new RuntimeException("Không tìm thấy chi nhánh phù hợp.");
        }

        // 3. Tạo record Cứu hộ mới
        Rescue rescue = new Rescue();
        
        // FIX LỖI 2 & 3: Ép kiểu Long từ Dto về Integer bằng .intValue()
        rescue.setCustomer(userRepository.findById(dto.getCustomerId().intValue())
                .orElseThrow(() -> new RuntimeException("Không tìm thấy user")));
                
        rescue.setVehicle(vehicleRepository.findById(dto.getVehicleId().intValue())
                .orElseThrow(() -> new RuntimeException("Không tìm thấy xe")));
                
        rescue.setBranch(nearestBranch);
        
        // Cập nhật tọa độ cho chuẩn với kiểu Double trong Entity Rescue
        rescue.setLatitude(dto.getLatitude().doubleValue());
        rescue.setLongitude(dto.getLongitude().doubleValue());
        
        rescue.setIssueDescription(dto.getIssueDescription());
        rescue.setStatus("PENDING"); 

        Rescue savedRescue = rescueRepository.save(rescue);
        
        messagingTemplate.convertAndSend("/topic/branches/" + nearestBranch.getId() + "/rescues", savedRescue);

        return savedRescue;
    }

    // Lấy các ca cứu hộ theo Chi Nhánh 
    public List<Rescue> getRescuesByBranch(Long branchId) {
        return rescueRepository.findByBranchIdOrderByCreatedAtDesc(branchId);
    }

    // ── CÔNG THỨC HAVERSINE ──
    private double calculateHaversine(double lat1, double lon1, double lat2, double lon2) {
        final int R = 6371; // Bán kính trái đất (Kilometers)
        double latDistance = Math.toRadians(lat2 - lat1);
        double lonDistance = Math.toRadians(lon2 - lon1);
        
        double a = Math.sin(latDistance / 2) * Math.sin(latDistance / 2)
                 + Math.cos(Math.toRadians(lat1)) * Math.cos(Math.toRadians(lat2))
                 * Math.sin(lonDistance / 2) * Math.sin(lonDistance / 2);
                 
        double c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
        return R * c;
    }
}