package com.carebike.backend.features.category.controller;

import com.carebike.backend.features.category.dto.CategoryDto;
import com.carebike.backend.features.category.dto.CategoryRequest;
import com.carebike.backend.features.category.service.CategoryService;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/categories")
@RequiredArgsConstructor
public class CategoryController {
    private final CategoryService service;

    @GetMapping
    public List<CategoryDto> getAllCategories() {
        return service.getAllCategories();
    }

    @PostMapping
    public CategoryDto createCategory(@RequestBody CategoryRequest request) {
        return service.createCategory(request);
    }

    @DeleteMapping("/{id}")
    public void deleteCategory(@PathVariable Integer id) {
        service.deleteCategory(id);
    }
}
