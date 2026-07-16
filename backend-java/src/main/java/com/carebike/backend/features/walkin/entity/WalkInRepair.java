package com.carebike.backend.features.walkin.entity;

import com.carebike.backend.features.branch.entity.Branch;
import jakarta.persistence.*;
import lombok.Data;

import java.math.BigDecimal;
import java.time.LocalDateTime;

@Entity
@Table(name = "walk_in_repairs")
@Data
public class WalkInRepair {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    @ManyToOne
    @JoinColumn(name = "branch_id", nullable = false)
    private Branch branch;

    @Column(name = "customer_name", nullable = false, columnDefinition = "NVARCHAR(255)")
    private String customerName;

    @Column(name = "customer_phone", nullable = false, length = 30)
    private String customerPhone;

    @Column(name = "vehicle_name", nullable = false, columnDefinition = "NVARCHAR(255)")
    private String vehicleName;

    @Column(name = "vehicle_plate", nullable = false, length = 30)
    private String vehiclePlate;

    @Column(name = "engine_capacity", length = 50)
    private String engineCapacity;

    @Column(name = "current_km")
    private Integer currentKm;

    @Column(name = "repair_date", nullable = false)
    private LocalDateTime repairDate = LocalDateTime.now();

    @Column(name = "completed_at")
    private LocalDateTime completedAt;

    @Column(name = "staff_code", length = 20)
    private String staffCode;

    @Column(name = "staff_name", columnDefinition = "NVARCHAR(255)")
    private String staffName;

    @Column(name = "invoice_details", columnDefinition = "NVARCHAR(MAX)")
    private String invoiceDetails;

    @Column(name = "total_cost", precision = 12, scale = 2)
    private BigDecimal totalCost;

    @Column(nullable = false, length = 20)
    private String status = "PAYING";
}
