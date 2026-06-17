package com.carebike.backend.features.rescue.dto;

import lombok.Data;

@Data
public class RescueRequestDto {
    private Long customerId;
    private Long vehicleId;
    private Double latitude;
    private Double longitude;
    private String issueDescription;
}