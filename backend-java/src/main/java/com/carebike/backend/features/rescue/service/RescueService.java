package com.carebike.backend.features.rescue.service;

import com.carebike.backend.features.rescue.dto.RescueRequestDto;
import com.carebike.backend.features.rescue.entity.Rescue;
import com.carebike.backend.features.rescue.repository.RescueRepository;

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

    @Autowired
    private com.carebike.backend.features.staff.repository.ShiftRepository shiftRepository;

    @Autowired
    private com.carebike.backend.features.websocket.service.WebSocketEventService webSocketEventService;

    @Autowired
    private com.carebike.backend.features.staff.service.StaffAssignmentService staffAssignmentService;

    // 1. Xóa @Autowired ở đây

    // 2. Thêm hàm Setter này để tiêm Bean một cách an toàn và trì hoãn (Lazy)

    @Transactional
    public Rescue createRescueRequest(RescueRequestDto dto) {
        if (dto.getLatitude() == null || dto.getLongitude() == null) {
            throw new RuntimeException("Your current location is required to request rescue assistance.");
        }
        if (dto.getCustomerId() == null) {
            throw new RuntimeException("Customer information is required.");
        }
        if (dto.getVehicleId() == null) {
            throw new RuntimeException("Vehicle information is required.");
        }

        if (branchRepository.count() == 0) {
            throw new RuntimeException("No CareBike branches are available.");
        }
        // 1. Lấy tất cả chi nhánh
        List<Branch> allBranches = branchRepository.findAll();

        if (allBranches.isEmpty()) {
            throw new RuntimeException("Hiện không có chi nhánh nào hoạt động.");
        }

        // Sắp xếp chi nhánh theo khoảng cách tăng dần
        allBranches.sort((b1, b2) -> {
            if (b1.getLatitude() == null || b1.getLongitude() == null) return 1;
            if (b2.getLatitude() == null || b2.getLongitude() == null) return -1;
            double d1 = calculateHaversine(dto.getLatitude().doubleValue(), dto.getLongitude().doubleValue(), b1.getLatitude().doubleValue(), b1.getLongitude().doubleValue());
            double d2 = calculateHaversine(dto.getLatitude().doubleValue(), dto.getLongitude().doubleValue(), b2.getLatitude().doubleValue(), b2.getLongitude().doubleValue());
            return Double.compare(d1, d2);
        });

        // Xác định ca hiện tại
        java.time.LocalTime now = java.time.LocalTime.now();
        int hour = now.getHour();
        String currentShiftType = "MORNING";
        if (hour >= 14 && hour < 22) {
            currentShiftType = "AFTERNOON";
        } else if (hour >= 22 || hour < 6) {
            currentShiftType = "NIGHT";
        }
        
        java.time.LocalDate shiftDate = java.time.LocalDate.now();
        if (hour < 6) {
            shiftDate = shiftDate.minusDays(1);
        }

        Branch assignedBranch = null;
        com.carebike.backend.features.staff.entity.Staff assignedStaff = null;

        // Quét tìm chi nhánh gần nhất có nhân viên FREE
        for (Branch branch : allBranches) {
            if (branch.getLatitude() == null || branch.getLongitude() == null) continue;
            
            List<com.carebike.backend.features.staff.entity.Staff> freeStaff = shiftRepository.findFreeStaffInShift(branch.getId(), shiftDate, currentShiftType);
            if (!freeStaff.isEmpty()) {
                assignedBranch = branch;
                // Có thể random hoặc lấy người đầu tiên
                assignedStaff = staffAssignmentService.assignRescue(branch.getId(), java.time.LocalDateTime.now());
                break;
            }
        }

        // Nếu tất cả chi nhánh đều bận, đẩy về chi nhánh gần nhất (không gán staff)
        if (assignedBranch == null || assignedStaff == null) {
            throw new RuntimeException("No available rescue staff were found at any branch. Please try again shortly.");
        }

        // 3. Tạo record Cứu hộ mới
        Rescue rescue = new Rescue();

        // FIX LỖI 2 & 3: Ép kiểu Long từ Dto về Integer bằng .intValue()
        rescue.setCustomer(userRepository.findById(dto.getCustomerId().intValue())
                .orElseThrow(() -> new RuntimeException("Không tìm thấy user")));

        rescue.setVehicle(vehicleRepository.findById(dto.getVehicleId().intValue())
                .orElseThrow(() -> new RuntimeException("Không tìm thấy xe")));

        rescue.setBranch(assignedBranch);

        // Cập nhật tọa độ cho chuẩn với kiểu Double trong Entity Rescue
        rescue.setLatitude(dto.getLatitude().doubleValue());
        rescue.setLongitude(dto.getLongitude().doubleValue());

        rescue.setIssueDescription(dto.getIssueDescription());
        
        if (assignedStaff != null) {
            rescue.setStaffCode(assignedStaff.getStaffCode());
            rescue.setAssignedStaffName(assignedStaff.getFullName());
            rescue.setAssignedStaffPhone(assignedStaff.getPhone());
            rescue.setDistanceKm(calculateHaversine(
                    dto.getLatitude(), dto.getLongitude(),
                    assignedBranch.getLatitude().doubleValue(), assignedBranch.getLongitude().doubleValue()));

            rescue.setStatus("ACCEPTED");
            // Đổi trạng thái nhân viên thành BUSY
            assignedStaff.setStatus(com.carebike.backend.features.staff.entity.StaffStatus.BUSY);
            staffRepository.save(assignedStaff);
        } else {
            rescue.setStatus("PENDING");
        }

        Rescue savedRescue = rescueRepository.save(rescue);

        // 3. Kiểm tra an toàn trước khi gọi hàm của WebSocket
        webSocketEventService.sendBranchTopic(assignedBranch.getId(), "rescues", savedRescue);
        webSocketEventService.sendBranchUpdate(assignedBranch.getId(), "RESCUE_UPDATED");
        notificationService.notifyRescueCreated(savedRescue);
        webSocketEventService.sendBranchUpdate(assignedBranch.getId(), "SHIFT_UPDATED");

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
        if ("COMPLETED".equalsIgnoreCase(status)) {
            rescue.setCompletedAt(java.time.LocalDateTime.now());
        }
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

    @Autowired
    private com.carebike.backend.features.customer.service.LoyaltyService loyaltyService;

    @Transactional(readOnly = true)
    public com.carebike.backend.features.staff.entity.Staff verifyAssignedStaff(Long rescueId, String staffCode) {
        Rescue rescue = rescueRepository.findById(rescueId)
                .orElseThrow(() -> new RuntimeException("Rescue request not found."));
        return validateAssignedStaff(rescue, staffCode);
    }
    @Transactional(readOnly = true)
    public com.carebike.backend.features.staff.entity.Staff getAssignedStaff(Long rescueId) {
        Rescue rescue = rescueRepository.findById(rescueId)
                .orElseThrow(() -> new RuntimeException("Rescue request not found."));
        String assignedCode = normalizeStaffCode(rescue.getStaffCode());
        if (assignedCode.isEmpty()) {
            throw new RuntimeException("No staff member has been assigned to this rescue request.");
        }
        return staffRepository.findByStaffCode(assignedCode)
                .orElseThrow(() -> new RuntimeException("The assigned staff member could not be found."));
    }


    private com.carebike.backend.features.staff.entity.Staff validateAssignedStaff(
            Rescue rescue, String submittedCode) {
        String assignedCode = normalizeStaffCode(rescue.getStaffCode());
        String normalizedSubmittedCode = normalizeStaffCode(submittedCode);

        if (assignedCode.isEmpty() || !assignedCode.equals(normalizedSubmittedCode)) {
            throw new RuntimeException(
                    "This staff code does not match the staff member assigned to this rescue request.");
        }

        com.carebike.backend.features.staff.entity.Staff assignedStaff = staffRepository
                .findByStaffCode(assignedCode)
                .orElseThrow(() -> new RuntimeException("The assigned staff member could not be found."));

        if (rescue.getBranch() == null || assignedStaff.getBranch() == null
                || !java.util.Objects.equals(rescue.getBranch().getId(), assignedStaff.getBranch().getId())) {
            throw new RuntimeException("The assigned staff member does not belong to this rescue branch.");
        }

        java.time.LocalDate shiftDate = currentShiftDate();
        String shiftType = currentShiftType();
        if (!shiftRepository.existsByStaffIdAndShiftDateAndShiftType(
                assignedStaff.getId(), shiftDate, shiftType)) {
            throw new RuntimeException("The assigned staff member is not scheduled for the current shift.");
        }

        return assignedStaff;
    }

    private String normalizeStaffCode(String staffCode) {
        return staffCode == null ? "" : staffCode.trim().toUpperCase(java.util.Locale.ROOT);
    }

    private String currentShiftType() {
        int hour = java.time.LocalTime.now().getHour();
        if (hour >= 14 && hour < 22) return "AFTERNOON";
        if (hour >= 22 || hour < 6) return "NIGHT";
        return "MORNING";
    }

    private java.time.LocalDate currentShiftDate() {
        java.time.LocalDate today = java.time.LocalDate.now();
        return java.time.LocalTime.now().getHour() < 6 ? today.minusDays(1) : today;
    }

    @Transactional
    public void completeRescue(Long rescueId, com.carebike.backend.features.rescue.dto.RescueCompleteRequest request) {
        Rescue rescue = rescueRepository.findById(rescueId)
                .orElseThrow(() -> new RuntimeException("Rescue request not found."));
        if ("COMPLETED".equalsIgnoreCase(rescue.getStatus())) {
            throw new RuntimeException("This rescue request has already been completed.");
        }

        com.carebike.backend.features.staff.entity.Staff assignedStaff =
                validateAssignedStaff(rescue, request.staffCode());

        // KIỂM TRA NHÂN VIÊN CÓ CA LÀM KHÔNG
        if (false && request.staffCode() != null && !request.staffCode().isBlank()) {
            com.carebike.backend.features.staff.entity.Staff staff = staffRepository.findByStaffCode(request.staffCode())
                    .orElseThrow(() -> new RuntimeException("Mã nhân viên không hợp lệ."));

            java.util.List<com.carebike.backend.features.staff.entity.Shift> shiftsToday =
                shiftRepository.findByStaffIdAndShiftDate(staff.getId(), java.time.LocalDate.now());

            if (shiftsToday == null || shiftsToday.isEmpty()) {
                throw new RuntimeException("Lỗi: Nhân viên " + staff.getFullName() + " không có lịch làm việc trong ngày hôm nay.");
            }
            
            // Set status to FREE
            staff.setStatus(com.carebike.backend.features.staff.entity.StaffStatus.FREE);
            staffRepository.save(staff);
            if (staff.getBranch() != null) {
                webSocketEventService.sendBranchUpdate(staff.getBranch().getId(), "SHIFT_UPDATED");
            }
        }

        // 1. Cập nhật trạng thái và thông tin bổ sung
        rescue = rescueRepository.findById(rescueId)
                .orElseThrow(() -> new RuntimeException("Không tìm thấy ca cứu hộ"));
        rescue.setStatus("COMPLETED");
        rescue.setCompletedAt(java.time.LocalDateTime.now());
        rescue.setStaffCode(assignedStaff.getStaffCode());
        rescue.setTimeMultiplier(request.timeMultiplier());
        rescue.setDistanceKm(request.distanceKm());
        rescue.setTransportFee(request.transportFee());
        // Do not save rescue yet, we will save it after calculating totalCost

        // 2. Tạo hóa đơn dưới dạng JSON
        com.fasterxml.jackson.databind.ObjectMapper mapper = new com.fasterxml.jackson.databind.ObjectMapper();
        com.fasterxml.jackson.databind.node.ObjectNode invoiceNode = mapper.createObjectNode();
        invoiceNode.put("sourceType", "RESCUE");

        // Customer & Vehicle Info
        invoiceNode.put("customerName", rescue.getCustomer() != null ? rescue.getCustomer().getFullName() : "");
        invoiceNode.put("customerPhone", rescue.getCustomer() != null ? rescue.getCustomer().getPhone() : "");
        invoiceNode.put("vehicleName", rescue.getVehicle() != null ? rescue.getVehicle().getBrand() + " " + rescue.getVehicle().getVehicleName() : "");
        invoiceNode.put("vehiclePlate", rescue.getVehicle() != null ? rescue.getVehicle().getLicensePlate() : "");
        invoiceNode.put("staffCode", assignedStaff.getStaffCode());
        String staffNameStr = assignedStaff.getFullName();
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
        webSocketEventService.sendBranchUpdate(rescue.getBranch().getId(), "MAINTENANCE_UPDATED");
        webSocketEventService.sendBranchUpdate(rescue.getBranch().getId(), "RESCUE_UPDATED");

        // 4. Tích điểm và cộng tổng chi tiêu
        if (totalCost != null && rescue.getCustomer() != null) {
            loyaltyService.addSpending(rescue.getCustomer(), totalCost);
        }

        assignedStaff.setStatus(com.carebike.backend.features.staff.entity.StaffStatus.FREE);
        staffRepository.save(assignedStaff);
        if (assignedStaff.getBranch() != null) {
            webSocketEventService.sendBranchUpdate(assignedStaff.getBranch().getId(), "SHIFT_UPDATED");
        }
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
