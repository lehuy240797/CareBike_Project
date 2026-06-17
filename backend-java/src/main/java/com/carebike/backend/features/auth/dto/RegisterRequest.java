package com.carebike.backend.features.auth.dto;

import lombok.Data;

@Data
public class RegisterRequest {
    private String email;
    private String fullName;
    private String phone;
}