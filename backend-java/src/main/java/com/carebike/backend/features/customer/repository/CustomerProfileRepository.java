package com.carebike.backend.features.customer.repository;

import com.carebike.backend.features.customer.entity.CustomerProfile;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface CustomerProfileRepository extends JpaRepository<CustomerProfile, Integer> {

    /** Find loyalty profile by the linked user's ID */
    Optional<CustomerProfile> findByUserId(Integer userId);
}
