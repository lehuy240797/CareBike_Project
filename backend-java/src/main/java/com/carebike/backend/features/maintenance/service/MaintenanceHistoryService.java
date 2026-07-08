package com.carebike.backend.features.maintenance.service;

import com.carebike.backend.features.auth.entity.User;
import com.carebike.backend.features.auth.repository.UserRepository;
import com.carebike.backend.features.branch.entity.Branch;
import com.carebike.backend.features.branch.repository.BranchRepository;
import com.carebike.backend.features.customer.service.LoyaltyService;
import com.carebike.backend.features.appointment.entity.Appointment;
import com.carebike.backend.features.appointment.repository.AppointmentRepository;
import com.carebike.backend.features.maintenance.dto.MaintenanceHistoryRequest;
import com.carebike.backend.features.maintenance.entity.MaintenanceHistory;
import com.carebike.backend.features.maintenance.repository.MaintenanceHistoryRepository;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.annotation.Lazy;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

@Service
public class MaintenanceHistoryService {

    private final MaintenanceHistoryRepository maintenanceRepository;
    private final UserRepository userRepository;
    private final BranchRepository branchRepository;
    private final AppointmentRepository appointmentRepository;
    private final LoyaltyService loyaltyService;
    private final ObjectMapper objectMapper;

    // Không dùng final
    private SimpMessagingTemplate messagingTemplate;

    // Bỏ messagingTemplate ra khỏi Constructor
    public MaintenanceHistoryService(
            MaintenanceHistoryRepository maintenanceRepository,
            UserRepository userRepository,
            BranchRepository branchRepository,
            AppointmentRepository appointmentRepository,
            LoyaltyService loyaltyService) {
        this.maintenanceRepository = maintenanceRepository;
        this.userRepository = userRepository;
        this.branchRepository = branchRepository;
        this.appointmentRepository = appointmentRepository;
        this.loyaltyService = loyaltyService;
        this.objectMapper = new ObjectMapper();
    }

    // Tiêm an toàn
    @Autowired(required = false)
    @Lazy
    public void setMessagingTemplate(SimpMessagingTemplate messagingTemplate) {
        this.messagingTemplate = messagingTemplate;
    }

    public List<MaintenanceHistory> getByCustomerId(Integer customerId) {
        return maintenanceRepository.findByCustomer_IdOrderByServiceDateDescIdDesc(customerId);
    }

    @Transactional
    public MaintenanceHistory create(MaintenanceHistoryRequest request) {
        User customer = userRepository.findById(request.getCustomerId())
                .orElseThrow(() -> new RuntimeException("Customer not found: " + request.getCustomerId()));

        Branch branch = null;
        if (request.getBranchId() != null) {
            branch = branchRepository.findById(request.getBranchId())
                    .orElseThrow(() -> new RuntimeException("Branch not found: " + request.getBranchId()));
        }

        Integer appointmentId = ensureCompletedAppointment(request, customer, branch);

        MaintenanceHistory record = new MaintenanceHistory();
        record.setCustomer(customer);
        record.setServiceDate(request.getServiceDate());
        record.setCurrentKm(request.getCurrentKm());
        record.setServiceDetails(withAppointmentId(request.getServiceDetails(), appointmentId));
        record.setTotalCost(request.getTotalCost());
        record.setBranch(branch);

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

    private Integer ensureCompletedAppointment(MaintenanceHistoryRequest request, User customer, Branch branch) {
        if (request.getAppointmentId() != null) {
            Appointment appointment = appointmentRepository.findById(request.getAppointmentId())
                    .orElseThrow(() -> new RuntimeException("Appointment not found: " + request.getAppointmentId()));
            appointment.setStatus("COMPLETED");
            return appointmentRepository.save(appointment).getId();
        }

        if (!Boolean.TRUE.equals(request.getCreateAppointment())) {
            return null;
        }

        if (branch == null) {
            throw new RuntimeException("Branch is required to create appointment from maintenance bill.");
        }

        Appointment appointment = new Appointment();
        appointment.setCustomer(customer);
        appointment.setBranch(branch);
        appointment.setAppointmentDate(
                request.getAppointmentDate() != null ? request.getAppointmentDate() : LocalDateTime.now()
        );
        appointment.setNote(
                request.getAppointmentNote() != null && !request.getAppointmentNote().isBlank()
                        ? request.getAppointmentNote()
                        : "Walk-in repair order"
        );
        appointment.setStatus(
                request.getAppointmentStatus() != null && !request.getAppointmentStatus().isBlank()
                        ? request.getAppointmentStatus().trim().toUpperCase()
                        : "COMPLETED"
        );
        return appointmentRepository.save(appointment).getId();
    }

    private String withAppointmentId(String serviceDetails, Integer appointmentId) {
        if (appointmentId == null || serviceDetails == null || !serviceDetails.trim().startsWith("{")) {
            return serviceDetails;
        }

        try {
            Map<String, Object> invoice = objectMapper.readValue(
                    serviceDetails,
                    new TypeReference<Map<String, Object>>() {}
            );
            invoice.put("sourceType", "APPOINTMENT");
            invoice.put("appointmentId", appointmentId);
            return objectMapper.writeValueAsString(invoice);
        } catch (Exception ignored) {
            return serviceDetails;
        }
    }
}
