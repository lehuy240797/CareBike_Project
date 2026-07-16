package com.carebike.backend.features.appointment.repository;

import com.carebike.backend.features.appointment.entity.Appointment;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.time.LocalDateTime;

@Repository
public interface AppointmentRepository extends JpaRepository<Appointment, Integer> {
    List<Appointment> findByCustomer_IdOrderByIdDesc(Integer customerId);
    List<Appointment> findByBranch_IdAndStatusOrderByAppointmentDateAsc(Integer branchId, String status);
    List<Appointment> findByBranch_IdOrderByIdDesc(Integer branchId);

    long countByAssignedStaff_IdAndStatusInAndAppointmentDateGreaterThanEqualAndAppointmentDateLessThan(
            Integer staffId,
            List<String> statuses,
            LocalDateTime shiftStart,
            LocalDateTime shiftEnd);
}
