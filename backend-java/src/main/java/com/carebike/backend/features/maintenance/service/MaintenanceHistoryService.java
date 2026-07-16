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
    private final com.carebike.backend.features.staff.repository.StaffRepository staffRepository;
    private final com.carebike.backend.features.staff.repository.ShiftRepository shiftRepository;
    private final com.carebike.backend.features.vehicle.repository.VehicleRepository vehicleRepository;

    // Không dùng final
    private SimpMessagingTemplate messagingTemplate;

    // Bỏ messagingTemplate ra khỏi Constructor
    public MaintenanceHistoryService(
            MaintenanceHistoryRepository maintenanceRepository,
            UserRepository userRepository,
            BranchRepository branchRepository,
            AppointmentRepository appointmentRepository,
            LoyaltyService loyaltyService,
            com.carebike.backend.features.staff.repository.StaffRepository staffRepository,
            com.carebike.backend.features.staff.repository.ShiftRepository shiftRepository,
            com.carebike.backend.features.vehicle.repository.VehicleRepository vehicleRepository) {
        this.maintenanceRepository = maintenanceRepository;
        this.userRepository = userRepository;
        this.branchRepository = branchRepository;
        this.appointmentRepository = appointmentRepository;
        this.loyaltyService = loyaltyService;
        this.staffRepository = staffRepository;
        this.shiftRepository = shiftRepository;
        this.vehicleRepository = vehicleRepository;
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

        // KIỂM TRA CA LÀM VIỆC CỦA NHÂN VIÊN
        if (request.getServiceDetails() != null && request.getServiceDetails().trim().startsWith("{")) {
            try {
                Map<String, Object> invoice = objectMapper.readValue(
                        request.getServiceDetails(),
                        new TypeReference<Map<String, Object>>() {}
                );
                String staffCode = (String) invoice.get("staffCode");
                if (staffCode != null && !staffCode.isBlank() && !staffCode.equals("N/A")) {
                    com.carebike.backend.features.staff.entity.Staff staff = staffRepository.findByStaffCode(staffCode)
                            .orElseThrow(() -> new RuntimeException("Mã nhân viên không hợp lệ."));
                    
                    List<com.carebike.backend.features.staff.entity.Shift> shiftsToday = 
                        shiftRepository.findByStaffIdAndShiftDate(staff.getId(), java.time.LocalDate.now());
                    
                    if (shiftsToday == null || shiftsToday.isEmpty()) {
                        throw new RuntimeException("Lỗi: Nhân viên " + staff.getFullName() + " không có lịch làm việc trong ngày hôm nay.");
                    }
                    
                    // Cập nhật trạng thái thành FREE
                    staff.setStatus(com.carebike.backend.features.staff.entity.StaffStatus.FREE);
                    staffRepository.save(staff);
                }
            } catch (com.fasterxml.jackson.core.JsonProcessingException ignored) {
                // Ignore parsing errors here, handled later or not critical for validation
            }
        }

        MaintenanceHistory record = new MaintenanceHistory();
        record.setCustomer(customer);
        record.setServiceDate(request.getServiceDate());
        record.setCurrentKm(request.getCurrentKm());
        record.setServiceDetails(withAppointmentId(request.getServiceDetails(), appointmentId));
        record.setTotalCost(request.getTotalCost());
        record.setBranch(branch);

        MaintenanceHistory saved = maintenanceRepository.save(record);

        if (request.getCurrentKm() != null && request.getCurrentKm() > 0 && appointmentId != null) {
            appointmentRepository.findById(appointmentId).ifPresent(appointment -> {
                com.carebike.backend.features.vehicle.entity.Vehicle vehicle = appointment.getVehicle();
                if (vehicle != null) {
                    vehicle.setCurrentKm(request.getCurrentKm());
                    vehicleRepository.save(vehicle);
                }
            });
        }

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
            appointment.setCompletedAt(LocalDateTime.now());
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
        if ("COMPLETED".equals(appointment.getStatus())) {
            appointment.setCompletedAt(LocalDateTime.now());
        }
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

    @Transactional
    public MaintenanceHistory createFromAppointment(Integer appointmentId) {
        Appointment appointment = appointmentRepository.findById(appointmentId)
                .orElseThrow(() -> new RuntimeException("Appointment not found: " + appointmentId));

        if (!"PAYING".equals(appointment.getStatus())) {
            throw new RuntimeException("Appointment is not in PAYING state");
        }

        appointment.setStatus("COMPLETED");
        appointment.setCompletedAt(LocalDateTime.now());
        appointmentRepository.save(appointment);

        MaintenanceHistory record = new MaintenanceHistory();
        record.setCustomer(appointment.getCustomer());
        record.setServiceDate(java.time.LocalDate.now());
        record.setCurrentKm(appointment.getCurrentKm());
        record.setServiceDetails(withAppointmentId(appointment.getInvoiceDetails(), appointmentId));
        record.setTotalCost(appointment.getTotalCost());
        record.setBranch(appointment.getBranch());

        MaintenanceHistory saved = maintenanceRepository.save(record);

        if (appointment.getCurrentKm() != null && appointment.getCurrentKm() > 0) {
            com.carebike.backend.features.vehicle.entity.Vehicle vehicle = appointment.getVehicle();
            if (vehicle != null) {
                vehicle.setCurrentKm(appointment.getCurrentKm());
                vehicleRepository.save(vehicle);
            }
        }

        if (appointment.getTotalCost() != null) {
            loyaltyService.addSpending(appointment.getCustomer(), appointment.getTotalCost());
        }

        return saved;
    }
}
