package com.carebike.backend.features.staff.service;

import com.carebike.backend.features.appointment.repository.AppointmentRepository;
import com.carebike.backend.features.rescue.repository.RescueRepository;
import com.carebike.backend.features.staff.entity.Staff;
import com.carebike.backend.features.staff.repository.ShiftRepository;
import org.springframework.stereotype.Service;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.util.Comparator;
import java.util.List;

@Service
public class StaffAssignmentService {

    private static final List<String> ACTIVE_APPOINTMENT_STATUSES =
            List.of("PENDING", "CONFIRMED", "PAYING", "COMPLETED");
    private static final List<String> ACTIVE_RESCUE_STATUSES =
            List.of("PENDING", "ACCEPTED", "IN_PROGRESS", "PAYING", "COMPLETED");

    private final ShiftRepository shiftRepository;
    private final AppointmentRepository appointmentRepository;
    private final RescueRepository rescueRepository;

    public StaffAssignmentService(
            ShiftRepository shiftRepository,
            AppointmentRepository appointmentRepository,
            RescueRepository rescueRepository) {
        this.shiftRepository = shiftRepository;
        this.appointmentRepository = appointmentRepository;
        this.rescueRepository = rescueRepository;
    }

    public Staff assignAppointment(Integer branchId, LocalDateTime appointmentDate) {
        ShiftWindow window = ShiftWindow.from(appointmentDate);
        List<Staff> scheduledStaff = shiftRepository.findStaffInShift(
                branchId, window.shiftDate(), window.shiftType());
        return selectLeastLoaded(scheduledStaff, window);
    }

    public Staff assignRescue(Integer branchId, LocalDateTime requestTime) {
        ShiftWindow window = ShiftWindow.from(requestTime);
        List<Staff> availableStaff = shiftRepository.findFreeStaffInShift(
                branchId, window.shiftDate(), window.shiftType());
        return selectLeastLoaded(availableStaff, window);
    }

    private Staff selectLeastLoaded(List<Staff> candidates, ShiftWindow window) {
        return candidates.stream()
                .min(Comparator
                        .comparingLong((Staff staff) -> activeWorkload(staff, window))
                        .thenComparing(Staff::getId))
                .orElse(null);
    }

    private long activeWorkload(Staff staff, ShiftWindow window) {
        long appointments = appointmentRepository
                .countByAssignedStaff_IdAndStatusInAndAppointmentDateGreaterThanEqualAndAppointmentDateLessThan(
                        staff.getId(), ACTIVE_APPOINTMENT_STATUSES, window.start(), window.end());
        long rescues = rescueRepository
                .countByStaffCodeIgnoreCaseAndStatusInAndCreatedAtGreaterThanEqualAndCreatedAtLessThan(
                        staff.getStaffCode(), ACTIVE_RESCUE_STATUSES, window.start(), window.end());
        return appointments + rescues;
    }

    private record ShiftWindow(
            LocalDate shiftDate,
            String shiftType,
            LocalDateTime start,
            LocalDateTime end) {

        private static ShiftWindow from(LocalDateTime dateTime) {
            LocalDate date = dateTime.toLocalDate();
            LocalTime time = dateTime.toLocalTime();

            if (time.isBefore(LocalTime.of(6, 0))) {
                LocalDate shiftDate = date.minusDays(1);
                return new ShiftWindow(
                        shiftDate,
                        "NIGHT",
                        shiftDate.atTime(22, 0),
                        date.atTime(6, 0));
            }
            if (time.isBefore(LocalTime.of(14, 0))) {
                return new ShiftWindow(
                        date,
                        "MORNING",
                        date.atTime(6, 0),
                        date.atTime(14, 0));
            }
            if (time.isBefore(LocalTime.of(22, 0))) {
                return new ShiftWindow(
                        date,
                        "AFTERNOON",
                        date.atTime(14, 0),
                        date.atTime(22, 0));
            }
            return new ShiftWindow(
                    date,
                    "NIGHT",
                    date.atTime(22, 0),
                    date.plusDays(1).atTime(6, 0));
        }
    }
}
