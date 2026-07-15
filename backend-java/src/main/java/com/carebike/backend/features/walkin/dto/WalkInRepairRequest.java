package com.carebike.backend.features.walkin.dto;

import lombok.Data;

import java.math.BigDecimal;

@Data
public class WalkInRepairRequest {
    private Integer branchId;
    private String customerName;
    private String customerPhone;
    private String vehicleName;
    private String vehiclePlate;
    private String engineCapacity;
    private Integer currentKm;
    private String staffCode;
    private String staffName;
    private String invoiceDetails;
    private BigDecimal totalCost;
}
