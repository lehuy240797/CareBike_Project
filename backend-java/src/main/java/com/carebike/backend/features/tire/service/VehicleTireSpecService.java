package com.carebike.backend.features.tire.service;

import com.carebike.backend.features.tire.dto.VehicleTireSpecRequest;
import com.carebike.backend.features.tire.dto.VehicleTireSpecResponse;
import com.carebike.backend.features.tire.entity.VehicleTireSpec;
import com.carebike.backend.features.tire.repository.VehicleTireSpecRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.util.Comparator;
import java.util.List;

@Service
@RequiredArgsConstructor
public class VehicleTireSpecService {

    private final VehicleTireSpecRepository repository;

    public List<VehicleTireSpecResponse> getAll() {
        return repository.findAll().stream()
                .sorted(Comparator
                        .comparing(VehicleTireSpec::getBrand, String.CASE_INSENSITIVE_ORDER)
                        .thenComparing(VehicleTireSpec::getVehicleName, String.CASE_INSENSITIVE_ORDER)
                        .thenComparing(spec -> spec.getEngineCapacity() == null ? 0 : spec.getEngineCapacity()))
                .map(this::toResponse)
                .toList();
    }

    public VehicleTireSpecResponse create(VehicleTireSpecRequest request) {
        validateRequired(request);
        ensureUnique(null, request);

        VehicleTireSpec spec = VehicleTireSpec.builder()
                .brand(clean(request.brand()))
                .vehicleName(clean(request.vehicleName()))
                .vehicleType(clean(request.vehicleType()))
                .engineCapacity(request.engineCapacity())
                .frontTireSize(clean(request.frontTireSize()))
                .rearTireSize(clean(request.rearTireSize()))
                .note(cleanNullable(request.note()))
                .build();

        return toResponse(repository.save(spec));
    }

    public VehicleTireSpecResponse update(Integer id, VehicleTireSpecRequest request) {
        validateRequired(request);

        VehicleTireSpec spec = repository.findById(id)
                .orElseThrow(() -> new RuntimeException("Vehicle tire specification was not found."));
        ensureUnique(id, request);

        spec.setBrand(clean(request.brand()));
        spec.setVehicleName(clean(request.vehicleName()));
        spec.setVehicleType(clean(request.vehicleType()));
        spec.setEngineCapacity(request.engineCapacity());
        spec.setFrontTireSize(clean(request.frontTireSize()));
        spec.setRearTireSize(clean(request.rearTireSize()));
        spec.setNote(cleanNullable(request.note()));

        return toResponse(repository.save(spec));
    }

    public void delete(Integer id) {
        if (!repository.existsById(id)) {
            throw new RuntimeException("Vehicle tire specification was not found.");
        }
        repository.deleteById(id);
    }

    private void ensureUnique(Integer currentId, VehicleTireSpecRequest request) {
        List<VehicleTireSpec> matches = repository.findByVehicleKey(
                clean(request.brand()),
                clean(request.vehicleName()),
                clean(request.vehicleType()),
                request.engineCapacity()
        );

        boolean duplicated = matches.stream()
                .anyMatch(spec -> currentId == null || !spec.getId().equals(currentId));
        if (duplicated) {
            throw new RuntimeException("This vehicle tire specification already exists.");
        }
    }

    private void validateRequired(VehicleTireSpecRequest request) {
        if (isBlank(request.brand())) {
            throw new RuntimeException("Brand is required.");
        }
        if (isBlank(request.vehicleName())) {
            throw new RuntimeException("Vehicle name is required.");
        }
        if (isBlank(request.vehicleType())) {
            throw new RuntimeException("Vehicle type is required.");
        }
        if (isBlank(request.frontTireSize())) {
            throw new RuntimeException("Front tire size is required.");
        }
        if (isBlank(request.rearTireSize())) {
            throw new RuntimeException("Rear tire size is required.");
        }
    }

    private VehicleTireSpecResponse toResponse(VehicleTireSpec spec) {
        return new VehicleTireSpecResponse(
                spec.getId(),
                spec.getBrand(),
                spec.getVehicleName(),
                spec.getVehicleType(),
                spec.getEngineCapacity(),
                spec.getFrontTireSize(),
                spec.getRearTireSize(),
                spec.getNote()
        );
    }

    private String clean(String value) {
        return value == null ? "" : value.trim();
    }

    private String cleanNullable(String value) {
        String cleaned = clean(value);
        return cleaned.isEmpty() ? null : cleaned;
    }

    private boolean isBlank(String value) {
        return value == null || value.trim().isEmpty();
    }
}
