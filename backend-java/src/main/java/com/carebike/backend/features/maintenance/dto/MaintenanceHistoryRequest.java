package com.carebike.backend.features.maintenance.dto;

import lombok.Data;
import java.math.BigDecimal;
import java.time.LocalDate;

@Data
public class MaintenanceHistoryRequest {
    private LocalDate serviceDate;
    private Integer currentKm;
    private String serviceDetails;
    private BigDecimal totalCost;
    private Integer customerId;
    private Integer branchId;
}
