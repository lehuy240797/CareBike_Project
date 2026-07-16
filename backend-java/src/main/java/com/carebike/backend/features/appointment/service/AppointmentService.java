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
    private final com.carebike.backend.features.staff.repository.StaffRepository staffRepository;
    private com.carebike.backend.features.maintenance.service.MaintenanceHistoryService maintenanceHistoryService;
    private final com.carebike.backend.features.websocket.service.WebSocketEventService webSocketEventService;
    private final com.carebike.backend.features.staff.service.StaffAssignmentService staffAssignmentService;

    // Không dùng final nữa để có thể gán giá trị sau khi khởi động
    private SimpMessagingTemplate messagingTemplate;

    // Bỏ messagingTemplate ra khỏi Constructor
    public AppointmentService(
            AppointmentRepository appointmentRepository,
            UserRepository userRepository,
            BranchRepository branchRepository,
            NotificationService notificationService,
            com.carebike.backend.features.vehicle.repository.VehicleRepository vehicleRepository,
            com.carebike.backend.features.staff.repository.StaffRepository staffRepository,
            com.carebike.backend.features.websocket.service.WebSocketEventService webSocketEventService,
            com.carebike.backend.features.staff.service.StaffAssignmentService staffAssignmentService) {
        this.appointmentRepository = appointmentRepository;
        this.userRepository = userRepository;
        this.branchRepository = branchRepository;
        this.notificationService = notificationService;
        this.vehicleRepository = vehicleRepository;
        this.staffRepository = staffRepository;
        this.webSocketEventService = webSocketEventService;
        this.staffAssignmentService = staffAssignmentService;
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

        java.time.LocalTime appointmentTime = request.getAppointmentDate().toLocalTime();
        java.time.LocalTime openingTime = java.time.LocalTime.of(8, 0);
        java.time.LocalTime closingTime = java.time.LocalTime.of(20, 0);
        if (appointmentTime.isBefore(openingTime) || appointmentTime.isAfter(closingTime)) {
            throw new RuntimeException(
                    "Appointments are available from 8:00 AM to 8:00 PM. "
                            + "Please use our 24/7 Rescue service for urgent issues outside working hours."
            );
        }
        Appointment appointment = new Appointment();

        com.carebike.backend.features.staff.entity.Staff assignedStaff =
                staffAssignmentService.assignAppointment(branch.getId(), request.getAppointmentDate());
        if (assignedStaff == null) {
            throw new RuntimeException(
                    "No staff member is scheduled for the selected appointment time. Please choose another time.");
        }
        appointment.setCustomer(customer);
        appointment.setBranch(branch);

        if (request.getVehicleId() != null) {
        appointment.setAssignedStaff(assignedStaff);
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
        webSocketEventService.sendBranchUpdate(branch.getId(), "APPOINTMENT_UPDATED");

        // Kiểm tra an toàn trước khi gửi WebSocket
        if (messagingTemplate != null) {
            String destination = "/topic/branches/" + savedAppointment.getBranch().getId() + "/appointments";
            messagingTemplate.convertAndSend(destination, savedAppointment);
        }
        notificationService.notifyAppointmentCreated(savedAppointment);

        return savedAppointment;
    }

    public List<Appointment> getByCustomerId(Integer customerId) {
        return appointmentRepository.findByCustomer_IdOrderByIdDesc(customerId);
    }

    @Transactional
    public Appointment cancel(Integer id) {
        Appointment apt = appointmentRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Lịch hẹn không tồn tại: " + id));

        if (!"PENDING".equals(apt.getStatus()) && !"CONFIRMED".equals(apt.getStatus())) {
            throw new RuntimeException("Chỉ có thể hủy lịch hẹn khi đang chờ hoặc đã được xác nhận nhưng chưa tạo hóa đơn.");
        }
        if (apt.getInvoiceDetails() != null && !apt.getInvoiceDetails().isBlank()) {
            throw new RuntimeException("Không thể hủy lịch hẹn sau khi hóa đơn đã được tạo.");
        }

        apt.setStatus("CANCELLED");
        Appointment cancelledAppointment = appointmentRepository.save(apt);
        webSocketEventService.sendBranchUpdate(cancelledAppointment.getBranch().getId(), "APPOINTMENT_UPDATED");

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
        return appointmentRepository.findByBranch_IdOrderByIdDesc(branchId);
    }

    public boolean isAllStaffBusy(Integer branchId) {
        List<com.carebike.backend.features.staff.entity.Staff> branchStaff =
                staffRepository.findByBranchId(branchId);

        return !branchStaff.isEmpty()
                && branchStaff.stream().allMatch(staff ->
                        staff.getStatus() == com.carebike.backend.features.staff.entity.StaffStatus.BUSY);
    }

    @Transactional
    public Appointment updateStatus(Integer id, String newStatus) {
        Appointment apt = appointmentRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Lịch hẹn không tồn tại: " + id));
        apt.setStatus(newStatus);
        if ("COMPLETED".equalsIgnoreCase(newStatus)) {
            apt.setCompletedAt(java.time.LocalDateTime.now());
        }
        Appointment updatedAppointment = appointmentRepository.save(apt);
        webSocketEventService.sendBranchUpdate(updatedAppointment.getBranch().getId(), "APPOINTMENT_UPDATED");

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

        validateAssignedStaffForInvoice(appointment, (String) request.get("invoiceDetails"));

        appointment.setStatus("PAYING");
        appointment.setInvoiceDetails((String) request.get("invoiceDetails"));
        appointment.setTotalCost(new java.math.BigDecimal(request.get("totalCost").toString()));
        if (request.get("currentKm") != null) {
            appointment.setCurrentKm(((Number) request.get("currentKm")).intValue());
        }

        Appointment saved = appointmentRepository.save(appointment);

        if (saved.getBranch() != null) {
            webSocketEventService.sendBranchUpdate(saved.getBranch().getId(), "APPOINTMENT_UPDATED");
        }

        if (appointment.getInvoiceDetails() != null) {
            try {
                com.fasterxml.jackson.databind.ObjectMapper mapper = new com.fasterxml.jackson.databind.ObjectMapper();
                java.util.Map<String, Object> invoiceMap = mapper.readValue(appointment.getInvoiceDetails(), new com.fasterxml.jackson.core.type.TypeReference<java.util.Map<String, Object>>() {});
                String staffCode = (String) invoiceMap.get("staffCode");
                if (staffCode != null) {
                    staffRepository.findByStaffCode(staffCode).ifPresent(staff -> {
                        staff.setStatus(com.carebike.backend.features.staff.entity.StaffStatus.BUSY);
                        staffRepository.save(staff);
                        if (staff.getBranch() != null) {
                            webSocketEventService.sendBranchUpdate(staff.getBranch().getId(), "SHIFT_UPDATED");
                        }
                    });
                }
            } catch (Exception e) {
            }
        }

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

        if (appointment.getInvoiceDetails() != null) {
            try {
                com.fasterxml.jackson.databind.ObjectMapper mapper = new com.fasterxml.jackson.databind.ObjectMapper();
                java.util.Map<String, Object> invoiceMap = mapper.readValue(appointment.getInvoiceDetails(), new com.fasterxml.jackson.core.type.TypeReference<java.util.Map<String, Object>>() {});
                String staffCode = (String) invoiceMap.get("staffCode");
                if (staffCode != null) {
                    staffRepository.findByStaffCode(staffCode).ifPresent(staff -> {
                        staff.setStatus(com.carebike.backend.features.staff.entity.StaffStatus.FREE);
                        staffRepository.save(staff);
                        if (staff.getBranch() != null) {
                            webSocketEventService.sendBranchUpdate(staff.getBranch().getId(), "SHIFT_UPDATED");
                        }
                    });
                }
            } catch (Exception e) {
            }
        }

        if (appointment.getBranch() != null) {
            webSocketEventService.sendBranchUpdate(appointment.getBranch().getId(), "APPOINTMENT_UPDATED");
        }

        if (messagingTemplate != null) {
            String customerDestination = "/topic/customers/" + appointment.getCustomer().getId() + "/appointments";
            messagingTemplate.convertAndSend(customerDestination, appointment);
        }
        notificationService.notifyAppointmentStatusChanged(appointment);

        return history;
    }
    private void validateAssignedStaffForInvoice(Appointment appointment, String invoiceDetails) {
        com.carebike.backend.features.staff.entity.Staff assignedStaff = appointment.getAssignedStaff();
        if (assignedStaff == null) {
            return;
        }
        if (invoiceDetails == null || invoiceDetails.isBlank()) {
            throw new RuntimeException("Staff information is required for this appointment.");
        }

        try {
            com.fasterxml.jackson.databind.JsonNode invoice =
                    new com.fasterxml.jackson.databind.ObjectMapper().readTree(invoiceDetails);
            String submittedCode = invoice.path("staffCode").asText("").trim();
            if (!assignedStaff.getStaffCode().equalsIgnoreCase(submittedCode)) {
                throw new RuntimeException(
                        "This staff code does not match the staff member assigned to this appointment.");
            }
        } catch (RuntimeException exception) {
            throw exception;
        } catch (Exception exception) {
            throw new RuntimeException("The appointment invoice data is invalid.");
        }
    }
}


