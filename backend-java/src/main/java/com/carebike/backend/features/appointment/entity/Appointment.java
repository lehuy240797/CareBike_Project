package com.carebike.backend.features.appointment.entity;

import com.carebike.backend.features.auth.entity.User;
import com.carebike.backend.features.branch.entity.Branch;
import jakarta.persistence.*;
import lombok.Data;

import java.time.LocalDateTime;

@Entity
@Table(name = "appointments")
@Data
public class Appointment {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    @ManyToOne
    @JoinColumn(name = "customer_id", nullable = false)
    @com.fasterxml.jackson.annotation.JsonIgnore
    private User customer;

    @ManyToOne
    @JoinColumn(name = "branch_id", nullable = false)
    @com.fasterxml.jackson.annotation.JsonIgnore
    private Branch branch;

    @ManyToOne
    @JoinColumn(name = "vehicle_id")
    @com.fasterxml.jackson.annotation.JsonIgnore
    private com.carebike.backend.features.vehicle.entity.Vehicle vehicle;
    @ManyToOne(fetch = FetchType.EAGER)
    @JoinColumn(name = "assigned_staff_id")
    @com.fasterxml.jackson.annotation.JsonIgnore
    private com.carebike.backend.features.staff.entity.Staff assignedStaff;


    @Column(name = "appointment_date", nullable = false)
    private LocalDateTime appointmentDate;

    @Column(columnDefinition = "NVARCHAR(MAX)")
    private String note;

    @Column(columnDefinition = "NVARCHAR(MAX)")
    private String invoiceDetails;

    @Column(name = "total_cost", precision = 12, scale = 2)
    private java.math.BigDecimal totalCost;

    @Column(name = "current_km")
    private Integer currentKm;

    @Column(name = "completed_at")
    private LocalDateTime completedAt;

    /**
     * PENDING   → freshly booked
     * CONFIRMED → branch has acknowledged
     * PAYING    → branch sent temporary bill
     * COMPLETED → service done and paid
     * CANCELLED → cancelled by customer or branch
     */
    @Column(nullable = false, length = 20)
    private String status = "PENDING";

    @com.fasterxml.jackson.annotation.JsonProperty("customerName")
    public String getCustomerName() {
        return customer != null ? customer.getFullName() : null;
    }

    @com.fasterxml.jackson.annotation.JsonProperty("customerId")
    public Integer getCustomerId() {
        return customer != null ? customer.getId() : null;
    }

    @com.fasterxml.jackson.annotation.JsonProperty("customerPhone")
    public String getCustomerPhone() {
        return customer != null ? customer.getPhone() : null;
    }

    @com.fasterxml.jackson.annotation.JsonProperty("branchName")
    public String getBranchName() {
        return branch != null ? branch.getName() : null;
    }

    @com.fasterxml.jackson.annotation.JsonProperty("branchId")
    public Integer getBranchId() {
        return branch != null ? branch.getId() : null;
    }

    @com.fasterxml.jackson.annotation.JsonProperty("vehicleId")
    public Integer getVehicleId() {
        return vehicle != null ? vehicle.getId() : null;
    }

    @com.fasterxml.jackson.annotation.JsonProperty("vehicleName")
    public String getVehicleName() {
        return vehicle != null ? vehicle.getVehicleName() : null;
    }

    @com.fasterxml.jackson.annotation.JsonProperty("vehicleBrand")
    public String getVehicleBrand() {
        return vehicle != null ? vehicle.getBrand() : null;
    }

    @com.fasterxml.jackson.annotation.JsonProperty("vehiclePlate")
    public String getVehiclePlate() {
        return vehicle != null ? vehicle.getLicensePlate() : null;
    }

    @com.fasterxml.jackson.annotation.JsonProperty("engineCapacity")
    public Integer getEngineCapacity() {
        return vehicle != null ? vehicle.getEngineCapacity() : null;
    }

    @com.fasterxml.jackson.annotation.JsonProperty("assignedStaffId")
    public Integer getAssignedStaffId() {
        return assignedStaff != null ? assignedStaff.getId() : null;
    }

    @com.fasterxml.jackson.annotation.JsonProperty("assignedStaffCode")
    public String getAssignedStaffCode() {
        return assignedStaff != null ? assignedStaff.getStaffCode() : null;
    }

    @com.fasterxml.jackson.annotation.JsonProperty("assignedStaffName")
    public String getAssignedStaffName() {
        return assignedStaff != null ? assignedStaff.getFullName() : null;
    }
}
