package com.carebike.backend.features.maintenance.repository;

import com.carebike.backend.features.maintenance.entity.MaintenanceHistory;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface MaintenanceHistoryRepository extends JpaRepository<MaintenanceHistory, Integer> {

    /** Fetch all maintenance records for a given customer, newest first */
    List<MaintenanceHistory> findByCustomer_IdOrderByServiceDateDescIdDesc(Integer customerId);
}
