package com.carebike.backend.features.tire.controller;

import com.carebike.backend.features.tire.dto.VehicleTireSpecRequest;
import com.carebike.backend.features.tire.dto.VehicleTireSpecResponse;
import com.carebike.backend.features.tire.service.VehicleTireSpecService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequiredArgsConstructor
@RequestMapping("/api/vehicle-tire-specs")
public class VehicleTireSpecController {

    private final VehicleTireSpecService service;

    @GetMapping
    public List<VehicleTireSpecResponse> getAll() {
        return service.getAll();
    }

    @PostMapping
    public ResponseEntity<VehicleTireSpecResponse> create(@RequestBody VehicleTireSpecRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED).body(service.create(request));
    }

    @PutMapping("/{id}")
    public VehicleTireSpecResponse update(
            @PathVariable Integer id,
            @RequestBody VehicleTireSpecRequest request
    ) {
        return service.update(id, request);
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> delete(@PathVariable Integer id) {
        service.delete(id);
        return ResponseEntity.noContent().build();
    }
}
