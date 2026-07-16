package com.carebike.backend.features.sparepart.dto;

import java.math.BigDecimal;

public record SparePartResponse(
        Integer id,
        String name,
        BigDecimal price,
        String description,
        String imageUrl,
        Integer categoryId,
        String categoryName,
        Boolean isActive
) {
}