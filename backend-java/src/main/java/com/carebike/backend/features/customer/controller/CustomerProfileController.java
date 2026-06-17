package com.carebike.backend.features.customer.controller;

import com.carebike.backend.features.customer.entity.CustomerProfile;
import com.carebike.backend.features.customer.service.LoyaltyService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/customer-profiles")
public class CustomerProfileController {

    private final LoyaltyService loyaltyService;

    public CustomerProfileController(LoyaltyService loyaltyService) {
        this.loyaltyService = loyaltyService;
    }

    /**
     * GET /api/customer-profiles
     * List all loyalty profiles (admin view).
     */
    @GetMapping
    public ResponseEntity<List<CustomerProfile>> getAllProfiles() {
        return ResponseEntity.ok(loyaltyService.findAll());
    }

    /**
     * GET /api/customer-profiles/user/{userId}
     * Get the loyalty profile for a specific customer.
     * Returns 404 if the customer has never had a maintenance record.
     */
    @GetMapping("/user/{userId}")
    public ResponseEntity<CustomerProfile> getProfileByUser(@PathVariable Integer userId) {
        return loyaltyService.findByUserId(userId)
                .map(ResponseEntity::ok)
                .orElse(ResponseEntity.notFound().build());
    }
}
