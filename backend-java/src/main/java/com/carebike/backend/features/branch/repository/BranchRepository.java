package com.carebike.backend.features.branch.repository;

import com.carebike.backend.features.branch.entity.Branch;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface BranchRepository extends JpaRepository<Branch, Integer> {

    /**
     * Find a branch by its manager's user ID.
     * Used to check if a given user is already assigned to a branch.
     */
    Optional<Branch> findByManagerId(Integer managerId);

    /**
     * Collect all manager user IDs that are currently assigned to OTHER branches
     * (i.e., every branch except the one being edited).
     * Used to build the "available managers" list.
     */
    @Query("SELECT b.manager.id FROM Branch b WHERE b.manager IS NOT NULL AND b.id != :excludeBranchId")
    java.util.List<Integer> findManagerIdsAssignedToOtherBranches(@Param("excludeBranchId") Integer excludeBranchId);
}