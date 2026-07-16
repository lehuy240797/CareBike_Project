package com.carebike.backend.features.sparepart.controller;

import com.carebike.backend.features.sparepart.dto.SparePartRequest;
import com.carebike.backend.features.sparepart.dto.SparePartResponse;
import com.carebike.backend.features.sparepart.service.SparePartService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/spare-parts")
@RequiredArgsConstructor
@CrossOrigin(origins = "*") // Tạm thời mở CORS để test với React
public class SparePartController {

    private final SparePartService service;

    // GET /api/spare-parts
    @GetMapping
    public ResponseEntity<List<SparePartResponse>> getAll(
            @RequestParam(required = false) Integer categoryId,
            @RequestParam(required = false) String search,
            @RequestParam(required = false, defaultValue = "true") Boolean activeOnly) {
        return ResponseEntity.ok(service.getAllSpareParts(categoryId, search, activeOnly));
    }

    // POST /api/spare-parts
    // Lưu ý: Dùng @ModelAttribute thay vì @RequestBody vì React gửi FormData chứa File
    @PostMapping(consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public ResponseEntity<SparePartResponse> create(
            @ModelAttribute SparePartRequest request) {
        SparePartResponse response = service.createSparePart(request);
        return ResponseEntity.status(HttpStatus.CREATED).body(response);
    }

    // PUT /api/spare-parts/{id}
    @PutMapping(value = "/{id}", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public ResponseEntity<SparePartResponse> update(
            @PathVariable Integer id,
            @ModelAttribute SparePartRequest request) {
        SparePartResponse response = service.updateSparePart(id, request);
        return ResponseEntity.ok(response);
    }

    // DELETE /api/spare-parts/{id}
    @DeleteMapping("/{id}")
    public ResponseEntity<Void> delete(@PathVariable Integer id) {
        service.deleteSparePart(id);
        return ResponseEntity.noContent().build();
    }

    // PUT /api/spare-parts/{id}/toggle
    @PutMapping("/{id}/toggle")
    public ResponseEntity<SparePartResponse> toggleActive(@PathVariable Integer id) {
        return ResponseEntity.ok(service.toggleActive(id));
    }
}