package com.carebike.backend.features.chat.dto;
import lombok.Data;
@Data
public class ChatRequest {
    private Integer customerId;
    private String message;
}
