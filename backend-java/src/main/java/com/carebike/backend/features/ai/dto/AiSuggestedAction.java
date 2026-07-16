package com.carebike.backend.features.ai.dto;

public record AiSuggestedAction(
        String type,
        String label,
        String payload
) {
}
