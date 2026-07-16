package com.carebike.backend.features.maintenance.entity;

import com.carebike.backend.features.auth.entity.User;
import com.carebike.backend.features.branch.entity.Branch;
import jakarta.persistence.*;
import lombok.Data;

import java.math.BigDecimal;
import java.time.LocalDate;

@Entity
@Table(name = "maintenance_history")
@Data
public class MaintenanceHistory {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    /** Ngày bảo dưỡng */
    @Column(name = "service_date", nullable = false)
    private LocalDate serviceDate;

    /** Số ODO (km hiện tại) */
    @Column(name = "current_km")
    private Integer currentKm;

    /** Chi tiết dịch vụ — comma-separated or free text */
    @Column(name = "service_details", columnDefinition = "NVARCHAR(MAX)")
    private String serviceDetails;

    /** Tổng số tiền */
    @Column(name = "total_cost", precision = 15, scale = 2)
    private BigDecimal totalCost;

    /** Khách hàng chủ xe */
    @ManyToOne
    @JoinColumn(name = "customer_id", referencedColumnName = "id", nullable = false)
    private User customer;

    /** Chi nhánh thực hiện */
    @ManyToOne
    @JoinColumn(name = "branch_id", referencedColumnName = "id")
    private Branch branch;
}
