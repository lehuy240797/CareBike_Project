package com.carebike.backend.features.rescue.service;

import com.carebike.backend.features.rescue.dto.RescueRequestDto;
import com.carebike.backend.features.rescue.entity.Rescue;
import com.carebike.backend.features.rescue.repository.RescueRepository;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.context.annotation.Lazy;

// Import các Repository khác
import com.carebike.backend.features.branch.entity.Branch;
import com.carebike.backend.features.branch.repository.BranchRepository;
import com.carebike.backend.features.auth.repository.UserRepository;
import com.carebike.backend.features.vehicle.repository.VehicleRepository;
import com.carebike.backend.features.staff.repository.StaffRepository;
import com.carebike.backend.features.notification.service.NotificationService;

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
    private StaffRepository staffRepository;

    @Autowired
    private NotificationService notificationService;

    // 1. Xóa @Autowired ở đây
    private SimpMessagingTemplate messagingTemplate;

    // 2. Thêm hàm Setter này để tiêm Bean một cách an toàn và trì hoãn (Lazy)
    @Autowired(required = false)
    @Lazy
    public void setMessagingTemplate(SimpMessagingTemplate messagingTemplate) {
        this.messagingTemplate = messagingTemplate;
    }

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
                        branch.getLongitude().doubleValue());

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

        // 3. Kiểm tra an toàn trước khi gọi hàm của WebSocket
        if (messagingTemplate != null) {
            messagingTemplate.convertAndSend("/topic/branches/" + nearestBranch.getId() + "/rescues", savedRescue);
        }
        notificationService.notifyRescueCreated(savedRescue);

        return savedRescue;
    }

    // Lấy các ca cứu hộ theo Chi Nhánh
    public List<Rescue> getRescuesByBranch(Integer branchId) {
        return rescueRepository.findByBranchIdOrderByCreatedAtDesc(branchId);
    }

    // Lấy lịch sử cứu hộ theo Khách hàng
    public List<Rescue> getRescuesByCustomer(Integer customerId) {
        return rescueRepository.findByCustomerIdOrderByCreatedAtDesc(customerId);
    }

    @Transactional
    public Rescue updateRescueStatus(Long rescueId, String status) {
        Rescue rescue = rescueRepository.findById(rescueId)
                .orElseThrow(() -> new RuntimeException("Không tìm thấy ca cứu hộ"));
        rescue.setStatus(status);
        Rescue savedRescue = rescueRepository.save(rescue);
        notificationService.notifyRescueStatusChanged(savedRescue);
        return savedRescue;
    }

    @Transactional
    public Rescue acceptRescue(Long rescueId) {
        return updateRescueStatus(rescueId, "ACCEPTED");
    }

    @Autowired
    private com.carebike.backend.features.maintenance.repository.MaintenanceHistoryRepository maintenanceHistoryRepository;

    @Transactional
    public void completeRescue(Long rescueId, com.carebike.backend.features.rescue.dto.RescueCompleteRequest request) {
        // 1. Cập nhật trạng thái và thông tin bổ sung
        Rescue rescue = rescueRepository.findById(rescueId)
                .orElseThrow(() -> new RuntimeException("Không tìm thấy ca cứu hộ"));
        rescue.setStatus("COMPLETED");
        rescue.setStaffCode(request.staffCode());
        rescue.setTimeMultiplier(request.timeMultiplier());
        rescue.setDistanceKm(request.distanceKm());
        rescue.setTransportFee(request.transportFee());
        rescue.setTransportFee(request.transportFee());
        // Do not save rescue yet, we will save it after calculating totalCost

        // 2. Tạo hóa đơn dưới dạng JSON
        com.fasterxml.jackson.databind.ObjectMapper mapper = new com.fasterxml.jackson.databind.ObjectMapper();
        com.fasterxml.jackson.databind.node.ObjectNode invoiceNode = mapper.createObjectNode();

        // Customer & Vehicle Info
        invoiceNode.put("customerName", rescue.getCustomer() != null ? rescue.getCustomer().getFullName() : "");
        invoiceNode.put("customerPhone", rescue.getCustomer() != null ? rescue.getCustomer().getPhone() : "");
        invoiceNode.put("vehicleName", rescue.getVehicle() != null ? rescue.getVehicle().getBrand() + " " + rescue.getVehicle().getVehicleName() : "");
        invoiceNode.put("vehiclePlate", rescue.getVehicle() != null ? rescue.getVehicle().getLicensePlate() : "");
        invoiceNode.put("staffCode", request.staffCode() != null ? request.staffCode() : "N/A");
        
        String staffNameStr = request.staffCode() != null ? request.staffCode() : "N/A";
        if (request.staffCode() != null) {
            com.carebike.backend.features.staff.entity.Staff staff = staffRepository.findByStaffCode(request.staffCode()).orElse(null);
            if (staff != null) {
                staffNameStr = staff.getFullName();
            }
        }
        invoiceNode.put("staffName", staffNameStr);
        
        java.time.format.DateTimeFormatter dtf = java.time.format.DateTimeFormatter.ofPattern("HH:mm - dd/MM/yyyy");
        invoiceNode.put("date", java.time.LocalDateTime.now().format(dtf));

        double multiplier = request.timeMultiplier() != null ? request.timeMultiplier() : 1.0;
        invoiceNode.put("timeMultiplier", multiplier);
        invoiceNode.put("laborCost", request.laborCost() != null ? request.laborCost() : java.math.BigDecimal.ZERO);
        invoiceNode.put("distanceKm", request.distanceKm() != null ? request.distanceKm() : 0.0);
        invoiceNode.put("transportFee", request.transportFee() != null ? request.transportFee() : java.math.BigDecimal.ZERO);

        java.math.BigDecimal totalCost = request.laborCost() != null ? request.laborCost() : java.math.BigDecimal.ZERO;

        com.fasterxml.jackson.databind.node.ArrayNode itemsNode = invoiceNode.putArray("items");
        if (request.items() != null) {
            for (com.carebike.backend.features.rescue.dto.RescueCompleteRequest.BillItem item : request.items()) {
                com.fasterxml.jackson.databind.node.ObjectNode itemNode = mapper.createObjectNode();
                itemNode.put("name", item.name());
                itemNode.put("quantity", item.quantity());
                java.math.BigDecimal itemPrice = item.price().multiply(java.math.BigDecimal.valueOf(multiplier));
                itemNode.put("price", itemPrice);
                itemsNode.add(itemNode);
                
                totalCost = totalCost.add(itemPrice.multiply(java.math.BigDecimal.valueOf(item.quantity())));
            }
        }
        
        if (request.transportFee() != null && request.transportFee().compareTo(java.math.BigDecimal.ZERO) > 0) {
            totalCost = totalCost.add(request.transportFee());
        }

        invoiceNode.put("totalAmount", totalCost);

        String detailsString = "";
        try {
            detailsString = mapper.writeValueAsString(invoiceNode);
        } catch (Exception e) {
            detailsString = "Error formatting invoice JSON";
        }

        // Update rescue with total cost and invoice details
        rescue.setTotalCost(totalCost);
        rescue.setInvoiceDetails(detailsString);
        Rescue savedRescue = rescueRepository.save(rescue);
        notificationService.notifyRescueStatusChanged(savedRescue);

        // 3. Lưu vào lịch sử bảo dưỡng
        com.carebike.backend.features.maintenance.entity.MaintenanceHistory history = 
            new com.carebike.backend.features.maintenance.entity.MaintenanceHistory();
        history.setServiceDate(java.time.LocalDate.now());
        history.setCurrentKm(0);
        history.setServiceDetails(detailsString);
        history.setTotalCost(totalCost);
        history.setCustomer(rescue.getCustomer());
        history.setBranch(rescue.getBranch());

        maintenanceHistoryRepository.save(history);
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
