package com.carebike.backend.features.appointment.service;

import com.carebike.backend.features.appointment.dto.AppointmentRequest;
import com.carebike.backend.features.appointment.entity.Appointment;
import com.carebike.backend.features.appointment.repository.AppointmentRepository;
import com.carebike.backend.features.auth.entity.User;
import com.carebike.backend.features.auth.repository.UserRepository;
import com.carebike.backend.features.branch.entity.Branch;
import com.carebike.backend.features.branch.repository.BranchRepository;
import com.carebike.backend.features.notification.service.NotificationService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.annotation.Lazy;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Service
public class AppointmentService {

    private final AppointmentRepository appointmentRepository;
    private final UserRepository userRepository;
    private final BranchRepository branchRepository;
    private final NotificationService notificationService;
    private final com.carebike.backend.features.vehicle.repository.VehicleRepository vehicleRepository;
    private com.carebike.backend.features.maintenance.service.MaintenanceHistoryService maintenanceHistoryService;

    // Không dùng final nữa để có thể gán giá trị sau khi khởi động
    private SimpMessagingTemplate messagingTemplate;

    // Bỏ messagingTemplate ra khỏi Constructor
    public AppointmentService(
            AppointmentRepository appointmentRepository,
            UserRepository userRepository,
            BranchRepository branchRepository,
            NotificationService notificationService,
            com.carebike.backend.features.vehicle.repository.VehicleRepository vehicleRepository) {
        this.appointmentRepository = appointmentRepository;
        this.userRepository = userRepository;
        this.branchRepository = branchRepository;
        this.notificationService = notificationService;
        this.vehicleRepository = vehicleRepository;
    }

    // Tiêm Bean vào một cách an toàn
    @Autowired(required = false)
    @Lazy
    public void setMessagingTemplate(SimpMessagingTemplate messagingTemplate) {
        this.messagingTemplate = messagingTemplate;
    }

    @Autowired
    @Lazy
    public void setMaintenanceHistoryService(com.carebike.backend.features.maintenance.service.MaintenanceHistoryService maintenanceHistoryService) {
        this.maintenanceHistoryService = maintenanceHistoryService;
    }

    @Transactional
    public Appointment create(AppointmentRequest request) {
        User customer = userRepository.findById(request.getCustomerId())
                .orElseThrow(() -> new RuntimeException("Khách hàng không tồn tại: " + request.getCustomerId()));

        Branch branch = branchRepository.findById(request.getBranchId())
                .orElseThrow(() -> new RuntimeException("Chi nhánh không tồn tại: " + request.getBranchId()));

        if (request.getAppointmentDate() == null) {
            throw new RuntimeException("Ngày hẹn không được để trống.");
        }

        Appointment appointment = new Appointment();
        appointment.setCustomer(customer);
        appointment.setBranch(branch);

        if (request.getVehicleId() != null) {
            com.carebike.backend.features.vehicle.entity.Vehicle vehicle = vehicleRepository.findById(request.getVehicleId())
                    .orElseThrow(() -> new RuntimeException("Phương tiện không tồn tại: " + request.getVehicleId()));
            appointment.setVehicle(vehicle);
        }

        appointment.setAppointmentDate(request.getAppointmentDate());
        appointment.setNote(request.getNote());
        appointment.setStatus(
                request.getStatus() == null || request.getStatus().isBlank()
                        ? "PENDING"
                        : request.getStatus().trim().toUpperCase()
        );

        Appointment savedAppointment = appointmentRepository.save(appointment);

        // Kiểm tra an toàn trước khi gửi WebSocket
        if (messagingTemplate != null) {
            String destination = "/topic/branches/" + savedAppointment.getBranch().getId() + "/appointments";
            messagingTemplate.convertAndSend(destination, savedAppointment);
        }
        notificationService.notifyAppointmentCreated(savedAppointment);

        return savedAppointment;
    }

    public List<Appointment> getByCustomerId(Integer customerId) {
        return appointmentRepository.findByCustomer_IdOrderByAppointmentDateDesc(customerId);
    }

    @Transactional
    public Appointment cancel(Integer id) {
        Appointment apt = appointmentRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Lịch hẹn không tồn tại: " + id));

        apt.setStatus("CANCELLED");
        Appointment cancelledAppointment = appointmentRepository.save(apt);

        if (messagingTemplate != null) {
            String branchDestination = "/topic/branches/" + cancelledAppointment.getBranch().getId() + "/appointments";
            messagingTemplate.convertAndSend(branchDestination, cancelledAppointment);
        }
        notificationService.notifyAppointmentCancelledByCustomer(cancelledAppointment);

        return cancelledAppointment;
    }

    public List<Appointment> getByBranchIdAndStatus(Integer branchId, String status) {
        return appointmentRepository.findByBranch_IdAndStatusOrderByAppointmentDateAsc(branchId, status);
    }

    public List<Appointment> getByBranchId(Integer branchId) {
        return appointmentRepository.findByBranch_IdOrderByAppointmentDateDesc(branchId);
    }

    @Transactional
    public Appointment updateStatus(Integer id, String newStatus) {
        Appointment apt = appointmentRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Lịch hẹn không tồn tại: " + id));
        apt.setStatus(newStatus);
        Appointment updatedAppointment = appointmentRepository.save(apt);

        if (messagingTemplate != null) {
            Integer customerId = updatedAppointment.getCustomer().getId();
            String customerDestination = "/topic/customers/" + customerId + "/appointments";
            messagingTemplate.convertAndSend(customerDestination, updatedAppointment);
        }
        notificationService.notifyAppointmentStatusChanged(updatedAppointment);

        return updatedAppointment;
    }

    @Transactional
    public Appointment saveInvoice(java.util.Map<String, Object> request) {
        Integer appointmentId = request.get("appointmentId") != null ? ((Number) request.get("appointmentId")).intValue() : null;
        Appointment appointment;

        if (appointmentId == null) {
            appointment = new Appointment();
            User customer = userRepository.findById(((Number) request.get("customerId")).intValue())
                    .orElseThrow(() -> new RuntimeException("Customer not found"));
            Branch branch = branchRepository.findById(((Number) request.get("branchId")).intValue())
                    .orElseThrow(() -> new RuntimeException("Branch not found"));
            appointment.setCustomer(customer);
            appointment.setBranch(branch);
            appointment.setAppointmentDate(java.time.LocalDateTime.now());
            appointment.setNote("Walk-in repair order");
            if (request.get("vehicleId") != null) {
                Integer vehicleId = ((Number) request.get("vehicleId")).intValue();
                appointment.setVehicle(vehicleRepository.findById(vehicleId).orElse(null));
            }
        } else {
            appointment = appointmentRepository.findById(appointmentId)
                    .orElseThrow(() -> new RuntimeException("Appointment not found"));
        }

        appointment.setStatus("PAYING");
        appointment.setInvoiceDetails((String) request.get("invoiceDetails"));
        appointment.setTotalCost(new java.math.BigDecimal(request.get("totalCost").toString()));
        if (request.get("currentKm") != null) {
            appointment.setCurrentKm(((Number) request.get("currentKm")).intValue());
        }

        Appointment saved = appointmentRepository.save(appointment);

        if (messagingTemplate != null) {
            String customerDestination = "/topic/customers/" + saved.getCustomer().getId() + "/appointments";
            messagingTemplate.convertAndSend(customerDestination, saved);
        }
        notificationService.notifyAppointmentStatusChanged(saved);

        return saved;
    }

    @Transactional
    public com.carebike.backend.features.maintenance.entity.MaintenanceHistory pay(Integer id) {
        Appointment appointment = appointmentRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Appointment not found"));

        if (!"PAYING".equals(appointment.getStatus())) {
            throw new RuntimeException("Chỉ có thể thanh toán khi ở trạng thái PAYING");
        }

        com.carebike.backend.features.maintenance.entity.MaintenanceHistory history =
            maintenanceHistoryService.createFromAppointment(id);

        if (messagingTemplate != null) {
            String customerDestination = "/topic/customers/" + appointment.getCustomer().getId() + "/appointments";
            messagingTemplate.convertAndSend(customerDestination, appointment);
        }
        notificationService.notifyAppointmentStatusChanged(appointment);

        return history;
    }
}
