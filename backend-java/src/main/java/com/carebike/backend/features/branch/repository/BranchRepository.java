package com.carebike.backend.features.branch.repository;

import com.carebike.backend.features.branch.entity.Branch;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface BranchRepository extends JpaRepository<Branch, Integer> {
    Optional<Branch> findByManagerId(Integer managerId);
    @Query("SELECT b.manager.id FROM Branch b WHERE b.manager IS NOT NULL AND b.id != :excludeBranchId")
    java.util.List<Integer> findManagerIdsAssignedToOtherBranches(@Param("excludeBranchId") Integer excludeBranchId);
}