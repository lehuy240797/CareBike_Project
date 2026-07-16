package com.carebike.backend.features.vehicle.entity;

import com.carebike.backend.features.auth.entity.User;
import jakarta.persistence.*;
import lombok.Data;

@Entity
@Table(name = "vehicles")
@Data
public class Vehicle {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    /** Hãng xe — e.g., Honda, Yamaha, Suzuki, SYM */
    @Column(nullable = false, columnDefinition = "NVARCHAR(100)")
    private String brand;

    /** Dòng xe — XE_SO or XE_TAY_GA */
    @Column(name = "vehicle_type", nullable = false, length = 50)
    private String vehicleType;

    /** Tên xe — e.g., Airblade, Exciter, Raider */
    @Column(name = "vehicle_name", nullable = false, columnDefinition = "NVARCHAR(150)")
    private String vehicleName;
    
    /** Biển số xe */
    @Column(name = "license_plate", length = 20)
    private String licensePlate;

    /** Phân khối (cc) */
    @Column(name = "engine_capacity")
    private Integer engineCapacity;

    /** Số km đã đi */
    @Column(name = "current_km")
    private Integer currentKm;

    @ManyToOne
    @JoinColumn(name = "owner_id", referencedColumnName = "id", nullable = false)
    private User owner;
}