package com.carebike.backend.features.vehicle.repository;
import com.carebike.backend.features.vehicle.entity.Vehicle;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import java.util.List;
import java.util.Optional;

@Repository
public interface VehicleRepository extends JpaRepository<Vehicle, Integer> {
    
    // Tìm toàn bộ xe của 1 khách hàng
    List<Vehicle> findByOwnerId(Integer ownerId);
    
    // Tìm xe theo Biển số
    Optional<Vehicle> findByLicensePlate(String licensePlate);
}