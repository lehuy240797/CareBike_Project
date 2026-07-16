package com.carebike.backend.features.sparepart.service;

import com.carebike.backend.features.sparepart.dto.SparePartRequest;
import com.carebike.backend.features.sparepart.dto.SparePartResponse;
import com.carebike.backend.features.sparepart.entity.SparePart;
import com.carebike.backend.features.sparepart.repository.SparePartRepository;
import com.carebike.backend.features.category.repository.CategoryRepository;
import com.carebike.backend.features.category.entity.Category;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.nio.file.StandardCopyOption;
import java.util.List;
import java.util.UUID;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class SparePartService {

    private final SparePartRepository repository;
    private final CategoryRepository categoryRepository;
    private final com.carebike.backend.features.websocket.service.WebSocketEventService webSocketEventService;
    // Sử dụng đường dẫn tương đối để dễ dàng chạy trên các máy khác nhau
    @org.springframework.beans.factory.annotation.Value("${app.upload.dir:uploads/images/}")
    private String UPLOAD_DIR;

    public List<SparePartResponse> getAllSpareParts(Integer categoryId, String search, Boolean activeOnly) {
        List<SparePart> parts;
        if (categoryId == null && (search == null || search.trim().isEmpty())) {
            parts = repository.findAll();
        } else if (categoryId == null && search != null && !search.trim().isEmpty()) {
            parts = repository.findByNameContainingIgnoreCase(search.trim());
        } else {
            parts = repository.searchAndFilter(categoryId, search);
        }

        if (Boolean.TRUE.equals(activeOnly)) {
            parts = parts.stream().filter(p -> p.getIsActive() == null || Boolean.TRUE.equals(p.getIsActive())).collect(Collectors.toList());
        }

        return parts.stream().map(this::mapToResponse).collect(Collectors.toList());
    }

    @Transactional
    public SparePartResponse createSparePart(SparePartRequest request) {
        try {
            String imageUrl = null;

            if (request.image() != null && !request.image().isEmpty()) {
                imageUrl = uploadImageLocally(request.image());
            }

            Category category = null;
            if (request.categoryId() != null) {
                category = categoryRepository.findById(request.categoryId())
                        .orElseThrow(() -> new RuntimeException("Không tìm thấy danh mục ID: " + request.categoryId()));
            }

            SparePart sparePart = SparePart.builder()
                    .name(request.name())
                    .price(request.price())
                    .description(request.description())
                    .imageUrl(imageUrl)
                    .category(category)
                    .build();

            SparePart saved = repository.save(sparePart);
            webSocketEventService.sendGlobalUpdate("SPARE_PART_UPDATED");
            return mapToResponse(saved);
        } catch (Exception e) {
            // Log lỗi chi tiết để xem tại sao bị 500
            System.err.println("LỖI KHI TẠO PHỤ TÙNG: " + e.getMessage());
            e.printStackTrace();
            throw new RuntimeException("Không thể tạo phụ tùng: " + e.getMessage());
        }
    }

    @Transactional
    public SparePartResponse updateSparePart(Integer id, SparePartRequest request) {
        SparePart sparePart = repository.findById(id)
                .orElseThrow(() -> new RuntimeException("Không tìm thấy phụ tùng ID: " + id));

        sparePart.setName(request.name());
        sparePart.setPrice(request.price());
        sparePart.setDescription(request.description());

        if (request.categoryId() != null) {
            Category category = categoryRepository.findById(request.categoryId())
                    .orElseThrow(() -> new RuntimeException("Không tìm thấy danh mục ID: " + request.categoryId()));
            sparePart.setCategory(category);
        } else {
            sparePart.setCategory(null);
        }

        if (request.image() != null && !request.image().isEmpty()) {
            if (sparePart.getImageUrl() != null) {
                deleteImageLocally(sparePart.getImageUrl());
            }
            String imageUrl = uploadImageLocally(request.image());
            sparePart.setImageUrl(imageUrl);
        }

        SparePart saved = repository.save(sparePart);
            webSocketEventService.sendGlobalUpdate("SPARE_PART_UPDATED");
            return mapToResponse(saved);
    }

    @Transactional
    public SparePartResponse toggleActive(Integer id) {
        SparePart sparePart = repository.findById(id)
                .orElseThrow(() -> new RuntimeException("Không tìm thấy phụ tùng ID: " + id));
        boolean currentStatus = sparePart.getIsActive() != null ? sparePart.getIsActive() : true;
        sparePart.setIsActive(!currentStatus);
        SparePart saved = repository.save(sparePart);
        webSocketEventService.sendGlobalUpdate("SPARE_PART_UPDATED");
        return mapToResponse(saved);
    }

    private String uploadImageLocally(MultipartFile file) {
        try {
            Path uploadPath = Paths.get(UPLOAD_DIR);
            if (!Files.exists(uploadPath)) {
                Files.createDirectories(uploadPath);
            }

            String uniqueFilename = UUID.randomUUID().toString() + "_" + file.getOriginalFilename();
            Path filePath = uploadPath.resolve(uniqueFilename);

            // Sao chép file
            Files.copy(file.getInputStream(), filePath, StandardCopyOption.REPLACE_EXISTING);

            return "/images/" + uniqueFilename;

        } catch (IOException e) {
            throw new RuntimeException("Lỗi ghi file: " + e.getMessage());
        }
    }

    private void deleteImageLocally(String imageUrl) {
        try {
            String filename = imageUrl.substring(imageUrl.lastIndexOf("/") + 1);
            Files.deleteIfExists(Paths.get(UPLOAD_DIR).resolve(filename));
        } catch (IOException e) {
            System.err.println("Không thể xóa file ảnh: " + e.getMessage());
        }
    }

    private SparePartResponse mapToResponse(SparePart sparePart) {
        String url = sparePart.getImageUrl();
        if (url != null) {
            // Lấy tên file ảnh
            String filename = url;
            if (url.contains("/")) {
                filename = url.substring(url.lastIndexOf("/") + 1);
            }
            
            // Tạo URL động dựa vào IP của request hiện tại
            try {
                String encodedFilename = java.net.URLEncoder.encode(filename, java.nio.charset.StandardCharsets.UTF_8.toString()).replace("+", "%20");
                String baseUrl = org.springframework.web.servlet.support.ServletUriComponentsBuilder.fromCurrentContextPath().build().toUriString();
                url = baseUrl + "/images/" + encodedFilename;
            } catch (Exception e) {
                // Đề phòng trường hợp gọi hàm ngoài context HTTP Request
                try {
                    String encodedFilename = java.net.URLEncoder.encode(filename, java.nio.charset.StandardCharsets.UTF_8.toString()).replace("+", "%20");
                    url = "http://localhost:8080/images/" + encodedFilename;
                } catch (Exception ex) {
                    url = "http://localhost:8080/images/" + filename;
                }
            }
        }
        return new SparePartResponse(
                sparePart.getId(),
                sparePart.getName(),
                sparePart.getPrice(),
                sparePart.getDescription(),
                url,
                sparePart.getCategory() != null ? sparePart.getCategory().getId() : null,
                sparePart.getCategory() != null ? sparePart.getCategory().getName() : null,
                sparePart.getIsActive() != null ? sparePart.getIsActive() : true
        );
    }
}
