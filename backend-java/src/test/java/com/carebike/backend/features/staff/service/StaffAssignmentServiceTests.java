package com.carebike.backend.features.staff.service;

import com.carebike.backend.features.appointment.repository.AppointmentRepository;
import com.carebike.backend.features.rescue.repository.RescueRepository;
import com.carebike.backend.features.staff.entity.Staff;
import com.carebike.backend.features.staff.repository.ShiftRepository;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.anyList;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.argThat;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.atLeastOnce;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class StaffAssignmentServiceTests {

    @Mock
    private ShiftRepository shiftRepository;
    @Mock
    private AppointmentRepository appointmentRepository;
    @Mock
    private RescueRepository rescueRepository;

    @Test
    void appointmentIsAssignedToTheStaffMemberWithLessWorkInThatShift() {
        Staff first = staff(1, "CBS-0001");
        Staff second = staff(2, "CBS-0002");
        LocalDateTime appointmentTime = LocalDateTime.of(2026, 7, 16, 10, 0);

        when(shiftRepository.findStaffInShift(7, LocalDate.of(2026, 7, 16), "MORNING"))
                .thenReturn(List.of(first, second));
        when(appointmentRepository
                .countByAssignedStaff_IdAndStatusInAndAppointmentDateGreaterThanEqualAndAppointmentDateLessThan(
                        anyInt(), anyList(), any(LocalDateTime.class), any(LocalDateTime.class)))
                .thenAnswer(invocation -> invocation.<Integer>getArgument(0) == 1 ? 1L : 0L);
        when(rescueRepository
                .countByStaffCodeIgnoreCaseAndStatusInAndCreatedAtGreaterThanEqualAndCreatedAtLessThan(
                        anyString(), anyList(), any(LocalDateTime.class), any(LocalDateTime.class)))
                .thenReturn(0L);

        StaffAssignmentService service =
                new StaffAssignmentService(shiftRepository, appointmentRepository, rescueRepository);

        Staff assigned = service.assignAppointment(7, appointmentTime);

        assertThat(assigned).isSameAs(second);
    }

    @Test
    void rescueUsesOnlyFreeStaffAndSkipsTheStaffMemberWhoAlreadyHasWork() {
        Staff first = staff(1, "CBS-0001");
        Staff second = staff(2, "CBS-0002");
        LocalDateTime requestTime = LocalDateTime.of(2026, 7, 16, 15, 0);

        when(shiftRepository.findFreeStaffInShift(7, LocalDate.of(2026, 7, 16), "AFTERNOON"))
                .thenReturn(List.of(first, second));
        when(appointmentRepository
                .countByAssignedStaff_IdAndStatusInAndAppointmentDateGreaterThanEqualAndAppointmentDateLessThan(
                        anyInt(), anyList(), any(LocalDateTime.class), any(LocalDateTime.class)))
                .thenReturn(0L);
        when(rescueRepository
                .countByStaffCodeIgnoreCaseAndStatusInAndCreatedAtGreaterThanEqualAndCreatedAtLessThan(
                        anyString(), anyList(), any(LocalDateTime.class), any(LocalDateTime.class)))
                .thenAnswer(invocation -> "CBS-0001".equals(invocation.getArgument(0)) ? 1L : 0L);

        StaffAssignmentService service =
                new StaffAssignmentService(shiftRepository, appointmentRepository, rescueRepository);

        Staff assigned = service.assignRescue(7, requestTime);

        assertThat(assigned).isSameAs(second);
        verify(shiftRepository)
                .findFreeStaffInShift(7, LocalDate.of(2026, 7, 16), "AFTERNOON");
        verify(rescueRepository, atLeastOnce())
                .countByStaffCodeIgnoreCaseAndStatusInAndCreatedAtGreaterThanEqualAndCreatedAtLessThan(
                        anyString(), argThat(statuses -> statuses.contains("COMPLETED")),
                        any(LocalDateTime.class), any(LocalDateTime.class));

    }

    private Staff staff(Integer id, String staffCode) {
        Staff staff = new Staff();
        staff.setId(id);
        staff.setStaffCode(staffCode);
        return staff;
    }
}
