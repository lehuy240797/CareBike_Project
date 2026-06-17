package com.carebike.backend.features.vehicle.dto;

import lombok.Data;

@Data
public class VehicleRequest {
    private Integer id; 
    private String brand;
    private String vehicleType;
    private String vehicleName;
    private String licensePlate;
    private Integer engineCapacity;
    private Integer currentKm;
}