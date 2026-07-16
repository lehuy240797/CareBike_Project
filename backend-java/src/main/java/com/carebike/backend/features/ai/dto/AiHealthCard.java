package com.carebike.backend.features.ai.dto;

public record AiHealthCard(
        String label,
        String status,
        String detail,
        String tone
) {
}
