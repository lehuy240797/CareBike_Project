package com.carebike.backend.features.appointment.service;

import com.carebike.backend.features.appointment.dto.AppointmentRequest;
import com.carebike.backend.features.appointment.entity.Appointment;
import com.carebike.backend.features.appointment.repository.AppointmentRepository;
import com.carebike.backend.features.auth.entity.User;
import com.carebike.backend.features.auth.repository.UserRepository;
import com.carebike.backend.features.branch.entity.Branch;
import com.carebike.backend.features.branch.repository.BranchRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import java.util.List;

@Service
public class AppointmentService {

    private final AppointmentRepository appointmentRepository;
    private final UserRepository userRepository;
    private final BranchRepository branchRepository;
    private final SimpMessagingTemplate messagingTemplate;

    public AppointmentService(
            AppointmentRepository appointmentRepository,
            UserRepository userRepository,
            BranchRepository branchRepository,
            SimpMessagingTemplate messagingTemplate) {
        this.appointmentRepository = appointmentRepository;
        this.userRepository = userRepository;
        this.branchRepository = branchRepository;
        this.messagingTemplate = messagingTemplate;
    }

    /** Book a new appointment and notify the branch in real-time */
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
        appointment.setAppointmentDate(request.getAppointmentDate());
        appointment.setNote(request.getNote());
        appointment.setStatus("PENDING");

        Appointment savedAppointment = appointmentRepository.save(appointment);

        // 1. Đẩy trọn vẹn object lịch hẹn mới qua WebSocket cho giao diện của chi nhánh
        String destination = "/topic/branches/" + savedAppointment.getBranch().getId() + "/appointments";
        messagingTemplate.convertAndSend(destination, savedAppointment);

        return savedAppointment;
    }

    /** Get all appointments for a customer (newest first) */
    public List<Appointment> getByCustomerId(Integer customerId) {
        return appointmentRepository.findByCustomerIdOrderByAppointmentDateDesc(customerId);
    }

    /** Cancel an appointment and notify Branch */
    @Transactional
    public Appointment cancel(Integer id) {
        Appointment apt = appointmentRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Lịch hẹn không tồn tại: " + id));
        
        apt.setStatus("CANCELLED");
        Appointment cancelledAppointment = appointmentRepository.save(apt);
        String branchDestination = "/topic/branches/" + cancelledAppointment.getBranch().getId() + "/appointments";
        messagingTemplate.convertAndSend(branchDestination, cancelledAppointment);

        return cancelledAppointment;
    }

    /** Get appointments for a branch by status */
    public List<Appointment> getByBranchIdAndStatus(Integer branchId, String status) {
        return appointmentRepository.findByBranchIdAndStatusOrderByAppointmentDateAsc(branchId, status);
    }

    /** Update appointment status and notify Customer */
    @Transactional
    public Appointment updateStatus(Integer id, String newStatus) {
        Appointment apt = appointmentRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Lịch hẹn không tồn tại: " + id));
        apt.setStatus(newStatus);
        Appointment updatedAppointment = appointmentRepository.save(apt);

        // Bắn thông báo Real-time lại cho khách hàng trên Mobile App biết trạng thái đã thay đổi
        Integer customerId = updatedAppointment.getCustomer().getId();
        String customerDestination = "/topic/customers/" + customerId + "/appointments";
        messagingTemplate.convertAndSend(customerDestination, updatedAppointment);
        
        return updatedAppointment;
    }
}