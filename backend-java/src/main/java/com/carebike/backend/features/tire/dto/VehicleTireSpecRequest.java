package com.carebike.backend.features.tire.dto;

public record VehicleTireSpecRequest(
        String brand,
        String vehicleName,
        String vehicleType,
        Integer engineCapacity,
        String frontTireSize,
        String rearTireSize,
        String note
) {
}
