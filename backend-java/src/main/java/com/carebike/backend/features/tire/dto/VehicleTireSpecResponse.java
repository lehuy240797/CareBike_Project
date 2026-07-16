package com.carebike.backend.features.tire.dto;

public record VehicleTireSpecResponse(
        Integer id,
        String brand,
        String vehicleName,
        String vehicleType,
        Integer engineCapacity,
        String frontTireSize,
        String rearTireSize,
        String note
) {
}
