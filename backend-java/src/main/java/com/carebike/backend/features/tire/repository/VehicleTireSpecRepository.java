package com.carebike.backend.features.tire.repository;

import com.carebike.backend.features.tire.entity.VehicleTireSpec;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface VehicleTireSpecRepository extends JpaRepository<VehicleTireSpec, Integer> {

    @Query("""
            SELECT s FROM VehicleTireSpec s
            WHERE LOWER(s.brand) = LOWER(:brand)
              AND LOWER(s.vehicleName) = LOWER(:vehicleName)
              AND LOWER(s.vehicleType) = LOWER(:vehicleType)
              AND (:engineCapacity IS NULL OR s.engineCapacity = :engineCapacity OR s.engineCapacity IS NULL)
            ORDER BY CASE WHEN s.engineCapacity = :engineCapacity THEN 0 ELSE 1 END
            """)
    List<VehicleTireSpec> findBestMatches(
            @Param("brand") String brand,
            @Param("vehicleName") String vehicleName,
            @Param("vehicleType") String vehicleType,
            @Param("engineCapacity") Integer engineCapacity
    );

    @Query("""
            SELECT s FROM VehicleTireSpec s
            WHERE LOWER(s.brand) = LOWER(:brand)
              AND LOWER(s.vehicleName) = LOWER(:vehicleName)
              AND (:engineCapacity IS NULL OR s.engineCapacity = :engineCapacity OR s.engineCapacity IS NULL)
            ORDER BY CASE WHEN LOWER(s.vehicleType) = LOWER(:vehicleType) THEN 0 ELSE 1 END,
                     CASE WHEN s.engineCapacity = :engineCapacity THEN 0 ELSE 1 END
            """)
    List<VehicleTireSpec> findBestMatchesByModel(
            @Param("brand") String brand,
            @Param("vehicleName") String vehicleName,
            @Param("vehicleType") String vehicleType,
            @Param("engineCapacity") Integer engineCapacity
    );

    @Query("""
            SELECT CASE WHEN COUNT(s) > 0 THEN true ELSE false END
            FROM VehicleTireSpec s
            WHERE LOWER(s.brand) = LOWER(:brand)
              AND LOWER(s.vehicleName) = LOWER(:vehicleName)
              AND LOWER(s.vehicleType) = LOWER(:vehicleType)
              AND ((:engineCapacity IS NULL AND s.engineCapacity IS NULL) OR s.engineCapacity = :engineCapacity)
            """)
    boolean existsByVehicleKey(
            @Param("brand") String brand,
            @Param("vehicleName") String vehicleName,
            @Param("vehicleType") String vehicleType,
            @Param("engineCapacity") Integer engineCapacity
    );

    @Query("""
            SELECT s FROM VehicleTireSpec s
            WHERE LOWER(s.brand) = LOWER(:brand)
              AND LOWER(s.vehicleName) = LOWER(:vehicleName)
              AND LOWER(s.vehicleType) = LOWER(:vehicleType)
              AND ((:engineCapacity IS NULL AND s.engineCapacity IS NULL) OR s.engineCapacity = :engineCapacity)
            """)
    List<VehicleTireSpec> findByVehicleKey(
            @Param("brand") String brand,
            @Param("vehicleName") String vehicleName,
            @Param("vehicleType") String vehicleType,
            @Param("engineCapacity") Integer engineCapacity
    );
}
