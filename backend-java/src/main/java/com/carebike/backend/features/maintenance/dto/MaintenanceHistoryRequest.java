package com.carebike.backend.features.maintenance.dto;

import lombok.Data;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;

@Data
public class MaintenanceHistoryRequest {
    private LocalDate serviceDate;
    private Integer currentKm;
    private String serviceDetails;
    private BigDecimal totalCost;
    private Integer customerId;
    private Integer branchId;
    private Integer appointmentId;
    private Boolean createAppointment;
    private LocalDateTime appointmentDate;
    private String appointmentNote;
    private String appointmentStatus;
}
