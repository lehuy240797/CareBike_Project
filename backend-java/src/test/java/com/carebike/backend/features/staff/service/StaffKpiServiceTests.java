package com.carebike.backend.features.staff.service;

import com.carebike.backend.features.appointment.entity.Appointment;
import com.carebike.backend.features.appointment.repository.AppointmentRepository;
import com.carebike.backend.features.rescue.entity.Rescue;
import com.carebike.backend.features.rescue.repository.RescueRepository;
import com.carebike.backend.features.staff.dto.StaffKpiResponse;
import com.carebike.backend.features.staff.entity.Staff;
import com.carebike.backend.features.staff.entity.StaffStatus;
import com.carebike.backend.features.staff.repository.StaffRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class StaffKpiServiceTests {

    @Mock
    private StaffRepository staffRepository;
    @Mock
    private AppointmentRepository appointmentRepository;
    @Mock
    private RescueRepository rescueRepository;

    private StaffKpiService service;

    @BeforeEach
    void setUp() {
        service = new StaffKpiService(staffRepository, appointmentRepository, rescueRepository);
    }

    @Test
    void countsOnlyCompletedJobsInsideTheSelectedDateRange() {
        Staff staff = new Staff();
        staff.setId(1);
        staff.setStaffCode("CBS-0001");
        staff.setFullName("Daniel Taylor");
        staff.setStatus(StaffStatus.FREE);

        Appointment includedAppointment = appointment(
                LocalDateTime.of(2026, 7, 16, 10, 0));
        Appointment excludedAppointment = appointment(
                LocalDateTime.of(2026, 6, 30, 10, 0));

        Rescue includedRescue = rescue(
                LocalDateTime.of(2026, 7, 20, 15, 0));
        Rescue excludedRescue = rescue(
                LocalDateTime.of(2026, 8, 1, 15, 0));

        when(staffRepository.findByBranchId(7)).thenReturn(List.of(staff));
        when(appointmentRepository.findByBranch_IdOrderByIdDesc(7))
                .thenReturn(List.of(includedAppointment, excludedAppointment));
        when(rescueRepository.findByBranchIdOrderByCreatedAtDesc(7))
                .thenReturn(List.of(includedRescue, excludedRescue));

        List<StaffKpiResponse> result = service.getBranchKpis(
                7, LocalDate.of(2026, 7, 1), LocalDate.of(2026, 7, 31));

        assertThat(result).hasSize(1);
        assertThat(result.getFirst().completedAppointments()).isEqualTo(1);
        assertThat(result.getFirst().completedRescues()).isEqualTo(1);
        assertThat(result.getFirst().totalCompleted()).isEqualTo(2);
    }

    @Test
    void rejectsAnInvalidDateRange() {
        assertThatThrownBy(() -> service.getBranchKpis(
                7, LocalDate.of(2026, 8, 1), LocalDate.of(2026, 7, 31)))
                .isInstanceOf(IllegalArgumentException.class);
    }

    private Appointment appointment(LocalDateTime completedAt) {
        Appointment appointment = new Appointment();
        appointment.setStatus("COMPLETED");
        appointment.setCompletedAt(completedAt);
        appointment.setAppointmentDate(completedAt);
        appointment.setInvoiceDetails("{\"staffCode\":\"CBS-0001\"}");
        return appointment;
    }

    private Rescue rescue(LocalDateTime completedAt) {
        Rescue rescue = new Rescue();
        rescue.setStatus("COMPLETED");
        rescue.setStaffCode("CBS-0001");
        rescue.setCompletedAt(completedAt);
        return rescue;
    }
}
