package com.carebike.backend.features.category.repository;

import com.carebike.backend.features.category.entity.Category;
import org.springframework.data.jpa.repository.JpaRepository;

public interface CategoryRepository extends JpaRepository<Category, Integer> {
}
