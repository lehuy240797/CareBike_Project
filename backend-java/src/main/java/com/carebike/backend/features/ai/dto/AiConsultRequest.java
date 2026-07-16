package com.carebike.backend.features.ai.dto;

import lombok.Data;

@Data
public class AiConsultRequest {
    private Integer customerId;
    private Integer vehicleId;
    private String message;
}
