package com.carebike.backend.features.appointment.service;

import com.carebike.backend.features.appointment.dto.AppointmentRequest;
import com.carebike.backend.features.appointment.entity.Appointment;
import com.carebike.backend.features.appointment.repository.AppointmentRepository;
import com.carebike.backend.features.auth.entity.User;
import com.carebike.backend.features.auth.repository.UserRepository;
import com.carebike.backend.features.branch.entity.Branch;
import com.carebike.backend.features.branch.repository.BranchRepository;
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

    // Không dùng final nữa để có thể gán giá trị sau khi khởi động
    private SimpMessagingTemplate messagingTemplate;

    // Bỏ messagingTemplate ra khỏi Constructor
    public AppointmentService(
            AppointmentRepository appointmentRepository,
            UserRepository userRepository,
            BranchRepository branchRepository) {
        this.appointmentRepository = appointmentRepository;
        this.userRepository = userRepository;
        this.branchRepository = branchRepository;
    }

    // Tiêm Bean vào một cách an toàn
    @Autowired(required = false)
    @Lazy
    public void setMessagingTemplate(SimpMessagingTemplate messagingTemplate) {
        this.messagingTemplate = messagingTemplate;
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
        appointment.setAppointmentDate(request.getAppointmentDate());
        appointment.setNote(request.getNote());
        appointment.setStatus("PENDING");

        Appointment savedAppointment = appointmentRepository.save(appointment);

        // Kiểm tra an toàn trước khi gửi WebSocket
        if (messagingTemplate != null) {
            String destination = "/topic/branches/" + savedAppointment.getBranch().getId() + "/appointments";
            messagingTemplate.convertAndSend(destination, savedAppointment);
        }

        return savedAppointment;
    }

    public List<Appointment> getByCustomerId(Integer customerId) {
        return appointmentRepository.findByCustomerIdOrderByAppointmentDateDesc(customerId);
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

        return cancelledAppointment;
    }

    public List<Appointment> getByBranchIdAndStatus(Integer branchId, String status) {
        return appointmentRepository.findByBranchIdAndStatusOrderByAppointmentDateAsc(branchId, status);
    }

    public List<Appointment> getByBranchId(Integer branchId) {
        return appointmentRepository.findByBranchIdOrderByAppointmentDateDesc(branchId);
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

        return updatedAppointment;
    }
}