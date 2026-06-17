package com.carebike.backend.features.appointment.repository;

import com.carebike.backend.features.appointment.entity.Appointment;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface AppointmentRepository extends JpaRepository<Appointment, Integer> {
    List<Appointment> findByCustomerIdOrderByAppointmentDateDesc(Integer customerId);
    List<Appointment> findByBranchIdAndStatusOrderByAppointmentDateAsc(Integer branchId, String status);
}
