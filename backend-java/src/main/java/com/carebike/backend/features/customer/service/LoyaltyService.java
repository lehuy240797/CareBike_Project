package com.carebike.backend.features.customer.service;

import com.carebike.backend.features.auth.entity.User;
import com.carebike.backend.features.customer.entity.CustomerProfile;
import com.carebike.backend.features.customer.repository.CustomerProfileRepository;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.util.List;
import java.util.Optional;

@Service
public class LoyaltyService {

    // Tier thresholds in VND
    private static final BigDecimal SILVER_THRESHOLD   = new BigDecimal("5000000");
    private static final BigDecimal GOLD_THRESHOLD     = new BigDecimal("15000000");
    private static final BigDecimal PLATINUM_THRESHOLD = new BigDecimal("30000000");

    // Points: 1 point per 100,000 VND
    private static final BigDecimal POINTS_DIVISOR = new BigDecimal("100000");

    private final CustomerProfileRepository profileRepository;

    public LoyaltyService(CustomerProfileRepository profileRepository) {
        this.profileRepository = profileRepository;
    }

    /**
     * Get (or lazily create) the loyalty profile for a customer.
     * Called after each maintenance record is saved.
     */
    public CustomerProfile getOrCreate(User user) {
        return profileRepository.findByUserId(user.getId())
                .orElseGet(() -> {
                    CustomerProfile p = new CustomerProfile();
                    p.setUser(user);
                    return profileRepository.save(p);
                });
    }

    /**
     * Add spending to a customer's profile, recalculate points and tier.
     * @param user        the customer
     * @param invoiceAmount the total cost of this maintenance session
     */
    public CustomerProfile addSpending(User user, BigDecimal invoiceAmount) {
        if (invoiceAmount == null || invoiceAmount.compareTo(BigDecimal.ZERO) <= 0) {
            return getOrCreate(user);
        }

        CustomerProfile profile = getOrCreate(user);

        // 1. Add to totalSpent
        profile.setTotalSpent(profile.getTotalSpent().add(invoiceAmount));

        // 2. Earn 1 point per 100,000 VND for THIS invoice
        int pointsEarned = invoiceAmount.divideToIntegralValue(POINTS_DIVISOR).intValue();
        profile.setAccumulatedPoints(profile.getAccumulatedPoints() + pointsEarned);

        // 3. Re-evaluate tier based on cumulative totalSpent
        profile.setMemberTier(calculateTier(profile.getTotalSpent()));

        return profileRepository.save(profile);
    }

    /** Get the loyalty profile for a given user ID (read-only, no auto-create) */
    public Optional<CustomerProfile> findByUserId(Integer userId) {
        return profileRepository.findByUserId(userId);
    }

    /** Get all profiles (for admin listing) */
    public List<CustomerProfile> findAll() {
        return profileRepository.findAll();
    }

    // ── Tier calculation ──────────────────────────────────────────────────────

    private String calculateTier(BigDecimal totalSpent) {
        if (totalSpent.compareTo(PLATINUM_THRESHOLD) >= 0) return "PLATINUM";
        if (totalSpent.compareTo(GOLD_THRESHOLD)     >= 0) return "GOLD";
        if (totalSpent.compareTo(SILVER_THRESHOLD)   >= 0) return "SILVER";
        return "STANDARD";
    }
}
