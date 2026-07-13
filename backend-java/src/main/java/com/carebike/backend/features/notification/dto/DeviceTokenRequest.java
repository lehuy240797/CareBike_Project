package com.carebike.backend.features.notification.dto;

import lombok.Data;

@Data
public class DeviceTokenRequest {
    private String token;
    private String platform;
}
