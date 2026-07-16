package com.carebike.backend.features.sparepart.repository;

import com.carebike.backend.features.sparepart.entity.SparePart;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

@Repository
public interface SparePartRepository extends JpaRepository<SparePart, Integer> {

    @Query("SELECT s FROM SparePart s WHERE (:categoryId IS NULL OR s.category.id = :categoryId) " +
           "AND (:keyword IS NULL OR LOWER(s.name) LIKE LOWER(CONCAT('%', :keyword, '%')))")
    List<SparePart> searchAndFilter(@Param("categoryId") Integer categoryId, @Param("keyword") String keyword);

    @Query("SELECT s FROM SparePart s WHERE (:categoryId IS NULL OR s.category.id = :categoryId) " +
           "AND (:keyword IS NULL OR LOWER(s.name) LIKE LOWER(CONCAT('%', :keyword, '%')) " +
           "OR LOWER(s.description) LIKE LOWER(CONCAT('%', :keyword, '%')))")
    List<SparePart> searchCatalogText(@Param("categoryId") Integer categoryId, @Param("keyword") String keyword);

    @Query("SELECT s FROM SparePart s WHERE (:keyword IS NULL OR LOWER(s.name) LIKE LOWER(CONCAT('%', :keyword, '%')) " +
           "OR LOWER(s.description) LIKE LOWER(CONCAT('%', :keyword, '%')))")
    List<SparePart> searchCatalogTextWithoutCategory(@Param("keyword") String keyword);

    List<SparePart> findByNameContainingIgnoreCase(String keyword);
}
