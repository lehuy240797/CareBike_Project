package com.carebike.backend.features.tire.entity;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@Entity
@Table(
        name = "vehicle_tire_specs",
        uniqueConstraints = @UniqueConstraint(
                name = "uk_vehicle_tire_specs_vehicle",
                columnNames = {"brand", "vehicle_name", "vehicle_type", "engine_capacity"}
        )
)
public class VehicleTireSpec {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    @Column(nullable = false, columnDefinition = "nvarchar(80)")
    private String brand;

    @Column(name = "vehicle_name", nullable = false, columnDefinition = "nvarchar(120)")
    private String vehicleName;

    @Column(name = "vehicle_type", nullable = false, columnDefinition = "nvarchar(50)")
    private String vehicleType;

    @Column(name = "engine_capacity")
    private Integer engineCapacity;

    @Column(name = "front_tire_size", nullable = false, columnDefinition = "nvarchar(60)")
    private String frontTireSize;

    @Column(name = "rear_tire_size", nullable = false, columnDefinition = "nvarchar(60)")
    private String rearTireSize;

    @Column(columnDefinition = "nvarchar(255)")
    private String note;
}
