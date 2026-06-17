package com.carebike.backend.features.customer.entity;

import com.carebike.backend.features.auth.entity.User;
import jakarta.persistence.*;
import lombok.Data;

import java.math.BigDecimal;

@Entity
@Table(name = "customer_profiles")
@Data
public class CustomerProfile {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    /** 1-to-1 with the User (customer) */
    @OneToOne
    @JoinColumn(name = "user_id", referencedColumnName = "id", nullable = false, unique = true)
    private User user;

    /** Total reward points accumulated */
    @Column(name = "accumulated_points", nullable = false)
    private Integer accumulatedPoints = 0;

    /**
     * Member tier based on totalSpent:
     * STANDARD  < 5,000,000
     * SILVER   >= 5,000,000
     * GOLD     >= 15,000,000
     * PLATINUM >= 30,000,000
     */
    @Column(name = "member_tier", nullable = false, length = 20)
    private String memberTier = "STANDARD";

    /** Cumulative total spent (VND) across all maintenance sessions */
    @Column(name = "total_spent", nullable = false, precision = 18, scale = 2)
    private BigDecimal totalSpent = BigDecimal.ZERO;
}
