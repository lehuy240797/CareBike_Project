package com.carebike.backend.features.staff.service;

import com.carebike.backend.features.appointment.entity.Appointment;
import com.carebike.backend.features.appointment.repository.AppointmentRepository;
import com.carebike.backend.features.rescue.entity.Rescue;
import com.carebike.backend.features.rescue.repository.RescueRepository;
import com.carebike.backend.features.staff.dto.StaffKpiResponse;
import com.carebike.backend.features.staff.entity.Staff;
import com.carebike.backend.features.staff.repository.StaffRepository;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.stereotype.Service;

import java.time.LocalDate;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;

@Service
public class StaffKpiService {

    private final StaffRepository staffRepository;
    private final AppointmentRepository appointmentRepository;
    private final RescueRepository rescueRepository;
    private final ObjectMapper objectMapper = new ObjectMapper();

    public StaffKpiService(
            StaffRepository staffRepository,
            AppointmentRepository appointmentRepository,
            RescueRepository rescueRepository
    ) {
        this.staffRepository = staffRepository;
        this.appointmentRepository = appointmentRepository;
        this.rescueRepository = rescueRepository;
    }

    public List<StaffKpiResponse> getBranchKpis(Integer branchId, LocalDate from, LocalDate to) {
        if (from != null && to != null && from.isAfter(to)) {
            throw new IllegalArgumentException("The KPI start date cannot be after the end date.");
        }
        List<Staff> staffs = staffRepository.findByBranchId(branchId).stream()
                .sorted(Comparator.comparing(Staff::getFullName, String.CASE_INSENSITIVE_ORDER))
                .toList();

        Map<String, StaffKpiCounter> counters = new LinkedHashMap<>();
        for (Staff staff : staffs) {
            counters.put(normalize(staff.getStaffCode()), new StaffKpiCounter(staff));
        }

        for (Appointment appointment : appointmentRepository.findByBranch_IdOrderByIdDesc(branchId)) {
            if (!"COMPLETED".equalsIgnoreCase(appointment.getStatus())) {
                continue;
            }
            if (!isWithinRange(appointmentCompletionDate(appointment), from, to)) {
                continue;
            }
            StaffKpiCounter counter = counters.get(normalize(readStaffCode(appointment.getInvoiceDetails())));
            if (counter != null) {
                counter.completedAppointments++;
            }
        }

        for (Rescue rescue : rescueRepository.findByBranchIdOrderByCreatedAtDesc(branchId)) {
            if (!"COMPLETED".equalsIgnoreCase(rescue.getStatus())) {
                continue;
            }
            if (!isWithinRange(rescueCompletionDate(rescue), from, to)) {
                continue;
            }
            StaffKpiCounter counter = counters.get(normalize(rescue.getStaffCode()));
            if (counter != null) {
                counter.completedRescues++;
            }
        }

        return counters.values().stream()
                .map(StaffKpiCounter::toResponse)
                .sorted(Comparator.comparingLong(StaffKpiResponse::totalCompleted).reversed()
                        .thenComparing(StaffKpiResponse::fullName, String.CASE_INSENSITIVE_ORDER))
                .toList();
    }
    private LocalDate appointmentCompletionDate(Appointment appointment) {
        if (appointment.getCompletedAt() != null) {
            return appointment.getCompletedAt().toLocalDate();
        }
        return appointment.getAppointmentDate() != null
                ? appointment.getAppointmentDate().toLocalDate()
                : null;
    }

    private LocalDate rescueCompletionDate(Rescue rescue) {
        if (rescue.getCompletedAt() != null) {
            return rescue.getCompletedAt().toLocalDate();
        }
        return rescue.getCreatedAt() != null ? rescue.getCreatedAt().toLocalDate() : null;
    }

    private boolean isWithinRange(LocalDate date, LocalDate from, LocalDate to) {
        if (from == null && to == null) {
            return true;
        }
        if (date == null) {
            return false;
        }
        return (from == null || !date.isBefore(from))
                && (to == null || !date.isAfter(to));
    }

    private String readStaffCode(String invoiceDetails) {
        if (invoiceDetails == null || invoiceDetails.isBlank()) {
            return "";
        }
        try {
            JsonNode invoice = objectMapper.readTree(invoiceDetails);
            return invoice.path("staffCode").asText("");
        } catch (Exception ignored) {
            return "";
        }
    }

    private String normalize(String staffCode) {
        return staffCode == null ? "" : staffCode.trim().toUpperCase(Locale.ROOT);
    }

    private static final class StaffKpiCounter {
        private final Staff staff;
        private long completedAppointments;
        private long completedRescues;

        private StaffKpiCounter(Staff staff) {
            this.staff = staff;
        }

        private StaffKpiResponse toResponse() {
            return new StaffKpiResponse(
                    staff.getId(),
                    staff.getStaffCode(),
                    staff.getFullName(),
                    staff.getStatus() != null ? staff.getStatus().name() : "FREE",
                    completedAppointments,
                    completedRescues,
                    completedAppointments + completedRescues
            );
        }
    }
}
