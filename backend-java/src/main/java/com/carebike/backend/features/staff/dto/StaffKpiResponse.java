package com.carebike.backend.features.staff.dto;

public record StaffKpiResponse(
        Integer staffId,
        String staffCode,
        String fullName,
        String status,
        long completedAppointments,
        long completedRescues,
        long totalCompleted
) {
}
