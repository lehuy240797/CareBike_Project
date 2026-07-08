package com.carebike.backend.features.rescue.dto;

import java.math.BigDecimal;
import java.util.List;

public record RescueCompleteRequest(
    List<BillItem> items,
    BigDecimal laborCost,
    String staffCode,
    Double timeMultiplier,
    Double distanceKm,
    BigDecimal transportFee
) {
    public record BillItem(
        Integer sparePartId,
        String name,
        Integer quantity,
        BigDecimal price
    ) {}
}
