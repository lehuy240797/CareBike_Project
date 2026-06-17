package com.carebike.backend.features.maintenance.service;

import com.carebike.backend.features.auth.entity.User;
import com.carebike.backend.features.auth.repository.UserRepository;
import com.carebike.backend.features.branch.entity.Branch;
import com.carebike.backend.features.branch.repository.BranchRepository;
import com.carebike.backend.features.customer.service.LoyaltyService;
import com.carebike.backend.features.maintenance.dto.MaintenanceHistoryRequest;
import com.carebike.backend.features.maintenance.entity.MaintenanceHistory;
import com.carebike.backend.features.maintenance.repository.MaintenanceHistoryRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.messaging.simp.SimpMessagingTemplate;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

@Service
public class MaintenanceHistoryService {

    private final MaintenanceHistoryRepository maintenanceRepository;
    private final UserRepository userRepository;
    private final BranchRepository branchRepository;
    private final LoyaltyService loyaltyService;
    private final SimpMessagingTemplate messagingTemplate;

    public MaintenanceHistoryService(
            MaintenanceHistoryRepository maintenanceRepository,
            UserRepository userRepository,
            BranchRepository branchRepository,
            LoyaltyService loyaltyService,
            SimpMessagingTemplate messagingTemplate) {
        this.maintenanceRepository = maintenanceRepository;
        this.userRepository = userRepository;
        this.branchRepository = branchRepository;
        this.loyaltyService = loyaltyService;
        this.messagingTemplate = messagingTemplate;
    }

    /** Get all maintenance records for a customer, newest first */
    public List<MaintenanceHistory> getByCustomerId(Integer customerId) {
        return maintenanceRepository.findByCustomerIdOrderByServiceDateDesc(customerId);
    }

    /**
     * Create a new maintenance record AND automatically update loyalty profile.
     * Wrapped in @Transactional — if loyalty update fails, the whole operation rolls back.
     */
    @Transactional
    public MaintenanceHistory create(MaintenanceHistoryRequest request) {
        User customer = userRepository.findById(request.getCustomerId())
                .orElseThrow(() -> new RuntimeException("Customer not found: " + request.getCustomerId()));

        MaintenanceHistory record = new MaintenanceHistory();
        record.setCustomer(customer);
        record.setServiceDate(request.getServiceDate());
        record.setCurrentKm(request.getCurrentKm());
        record.setServiceDetails(request.getServiceDetails());
        record.setTotalCost(request.getTotalCost());

        if (request.getBranchId() != null) {
            Branch branch = branchRepository.findById(request.getBranchId())
                    .orElseThrow(() -> new RuntimeException("Branch not found: " + request.getBranchId()));
            record.setBranch(branch);
        }

        MaintenanceHistory saved = maintenanceRepository.save(record);

        // ── Loyalty trigger ───────────────────────────────────────────────────
        // After saving the invoice, auto-update points + tier for the customer.
        if (request.getTotalCost() != null) {
            loyaltyService.addSpending(customer, request.getTotalCost());
        }

        // ====================================================================
        // BẮN TÍN HIỆU REAL-TIME CHO KHÁCH HÀNG SAU KHI SỬA XE XONG
        // ====================================================================
        String customerDestination = "/topic/customers/" + customer.getId() + "/appointments";
        
        Map<String, Object> notification = new HashMap<>();
        notification.put("status", "COMPLETED"); 
        notification.put("message", "Xe của bạn đã được bảo dưỡng xong!");

        // ÉP KIỂU (Object) TẠI ĐÂY ĐỂ TRÁNH LỖI AMBIGUOUS CỦA JAVA
        messagingTemplate.convertAndSend(customerDestination, (Object) notification);

        return saved;
    }
}