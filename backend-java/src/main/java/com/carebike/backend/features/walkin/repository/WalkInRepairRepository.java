package com.carebike.backend.features.walkin.repository;

import com.carebike.backend.features.walkin.entity.WalkInRepair;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface WalkInRepairRepository extends JpaRepository<WalkInRepair, Integer> {
    List<WalkInRepair> findByBranch_IdOrderByRepairDateDescIdDesc(Integer branchId);
}
