package com.carebike.backend.features.maintenance.service;

import com.carebike.backend.features.auth.entity.User;
import com.carebike.backend.features.auth.repository.UserRepository;
import com.carebike.backend.features.branch.entity.Branch;
import com.carebike.backend.features.branch.repository.BranchRepository;
import com.carebike.backend.features.customer.service.LoyaltyService;
import com.carebike.backend.features.maintenance.dto.MaintenanceHistoryRequest;
import com.carebike.backend.features.maintenance.entity.MaintenanceHistory;
import com.carebike.backend.features.maintenance.repository.MaintenanceHistoryRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.annotation.Lazy;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

@Service
public class MaintenanceHistoryService {

    private final MaintenanceHistoryRepository maintenanceRepository;
    private final UserRepository userRepository;
    private final BranchRepository branchRepository;
    private final LoyaltyService loyaltyService;

    // Không dùng final
    private SimpMessagingTemplate messagingTemplate;

    // Bỏ messagingTemplate ra khỏi Constructor
    public MaintenanceHistoryService(
            MaintenanceHistoryRepository maintenanceRepository,
            UserRepository userRepository,
            BranchRepository branchRepository,
            LoyaltyService loyaltyService) {
        this.maintenanceRepository = maintenanceRepository;
        this.userRepository = userRepository;
        this.branchRepository = branchRepository;
        this.loyaltyService = loyaltyService;
    }

    // Tiêm an toàn
    @Autowired(required = false)
    @Lazy
    public void setMessagingTemplate(SimpMessagingTemplate messagingTemplate) {
        this.messagingTemplate = messagingTemplate;
    }

    public List<MaintenanceHistory> getByCustomerId(Integer customerId) {
        return maintenanceRepository.findByCustomerIdOrderByServiceDateDesc(customerId);
    }

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

        if (request.getTotalCost() != null) {
            loyaltyService.addSpending(customer, request.getTotalCost());
        }

        // Kiểm tra null để tránh sập server nếu WebSocket chết
        if (messagingTemplate != null) {
            String customerDestination = "/topic/customers/" + customer.getId() + "/appointments";
            Map<String, Object> notification = new HashMap<>();
            notification.put("status", "COMPLETED");
            notification.put("message", "Xe của bạn đã được bảo dưỡng xong!");

            messagingTemplate.convertAndSend(customerDestination, (Object) notification);
        }

        return saved;
    }
}