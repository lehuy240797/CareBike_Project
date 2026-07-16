package com.carebike.backend.features.category.service;

import com.carebike.backend.features.category.dto.CategoryDto;
import com.carebike.backend.features.category.dto.CategoryRequest;
import com.carebike.backend.features.category.entity.Category;
import com.carebike.backend.features.category.repository.CategoryRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import java.util.List;

@Service
@RequiredArgsConstructor
public class CategoryService {
    private final CategoryRepository repository;
    private final com.carebike.backend.features.websocket.service.WebSocketEventService webSocketEventService;

    public List<CategoryDto> getAllCategories() {
        return repository.findAll().stream()
                .map(c -> new CategoryDto(c.getId(), c.getName(), c.getDescription()))
                .toList();
    }

    public CategoryDto createCategory(CategoryRequest request) {
        Category category = Category.builder()
                .name(request.name())
                .description(request.description())
                .build();
        category = repository.save(category);
        webSocketEventService.sendGlobalUpdate("SPARE_PART_UPDATED");
        return new CategoryDto(category.getId(), category.getName(), category.getDescription());
    }

    public void deleteCategory(Integer id) {
        repository.deleteById(id);
        webSocketEventService.sendGlobalUpdate("SPARE_PART_UPDATED");
    }
}
