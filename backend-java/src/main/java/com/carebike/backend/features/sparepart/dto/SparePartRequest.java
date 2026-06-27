package com.carebike.backend.features.sparepart.dto;

import org.springframework.web.multipart.MultipartFile;
import java.math.BigDecimal;

// Dùng record giúp tự động tạo Getter, Constructor chuẩn Java 21
public record SparePartRequest(
        String name,
        BigDecimal price,
        String description,
        Integer categoryId,
        MultipartFile image // Nhận file ảnh từ Frontend gửi lên
) {
}