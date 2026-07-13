package com.carebike.backend.features.appointment.dto;

import lombok.Data;
import java.time.LocalDateTime;

@Data
public class AppointmentRequest {
    private Integer customerId;
    private Integer branchId;
    private Integer vehicleId;
    private LocalDateTime appointmentDate;
    private String note;
    private String status;
}
