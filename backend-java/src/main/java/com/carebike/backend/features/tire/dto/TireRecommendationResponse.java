package com.carebike.backend.features.tire.dto;

import java.math.BigDecimal;
import java.util.List;

public record TireRecommendationResponse(
        Integer vehicleId,
        String brand,
        String vehicleName,
        TirePosition tirePosition,
        String tireSize,
        BigDecimal laborMin,
        BigDecimal laborMax,
        String quoteDisclaimer,
        List<TireQuoteOptionResponse> options
) {
}
