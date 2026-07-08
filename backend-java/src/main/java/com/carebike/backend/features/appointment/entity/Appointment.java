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

    @Column(name = "appointment_date", nullable = false)
    private LocalDateTime appointmentDate;

    @Column(columnDefinition = "TEXT")
    private String note;

    /**
     * PENDING   → freshly booked
     * CONFIRMED → branch has acknowledged
     * COMPLETED → service done
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
}
