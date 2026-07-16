package com.carebike.backend.features.tire.dto;

import java.math.BigDecimal;

public record TireQuoteOptionResponse(
        Integer id,
        String name,
        BigDecimal price,
        String description,
        String imageUrl,
        Integer categoryId,
        String tireSize,
        BigDecimal laborMin,
        BigDecimal laborMax,
        BigDecimal estimateMin,
        BigDecimal estimateMax,
        Integer fitConfidence,
        String fitReason
) {
}
