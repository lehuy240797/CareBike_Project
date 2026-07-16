package com.carebike.backend.features.tire.service;

import com.carebike.backend.features.sparepart.entity.SparePart;
import com.carebike.backend.features.sparepart.repository.SparePartRepository;
import com.carebike.backend.features.tire.dto.TirePosition;
import com.carebike.backend.features.tire.dto.TireQuoteOptionResponse;
import com.carebike.backend.features.tire.dto.TireRecommendationResponse;
import com.carebike.backend.features.tire.entity.VehicleTireSpec;
import com.carebike.backend.features.tire.repository.VehicleTireSpecRepository;
import com.carebike.backend.features.vehicle.entity.Vehicle;
import com.carebike.backend.features.vehicle.repository.VehicleRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.util.Comparator;
import java.util.List;
import java.util.Locale;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

@Service
@RequiredArgsConstructor
public class TireRecommendationService {

    private static final BigDecimal TIRE_REPLACEMENT_LABOR_MIN = BigDecimal.valueOf(50_000);
    private static final BigDecimal TIRE_REPLACEMENT_LABOR_MAX = BigDecimal.valueOf(100_000);
    private static final Pattern TIRE_SIZE_PATTERN = Pattern.compile("(\\d{2,3}/\\d{2,3}-\\d{2})");
    private static final int MAX_RECOMMENDATION_OPTIONS = 5;
    private static final int SIZE_MATCH_CONFIDENCE = 82;

    private final VehicleRepository vehicleRepository;
    private final VehicleTireSpecRepository tireSpecRepository;
    private final SparePartRepository sparePartRepository;

    @Value("${carebike.tire.category-id:6}")
    private Integer tireCategoryId;

    public TireRecommendationResponse getRecommendation(Integer vehicleId, TirePosition position) {
        if (vehicleId == null) {
            throw new RuntimeException("Please choose a vehicle before scanning the tire.");
        }
        validatePosition(position);

        Vehicle vehicle = vehicleRepository.findById(vehicleId)
                .orElseThrow(() -> new RuntimeException("Selected vehicle was not found."));

        String brand = trimToEmpty(vehicle.getBrand());
        String vehicleName = trimToEmpty(vehicle.getVehicleName());
        String vehicleType = trimToEmpty(vehicle.getVehicleType());
        VehicleTireSpec spec = findTireSpec(brand, vehicleName, vehicleType, vehicle.getEngineCapacity());

        return buildRecommendation(vehicle.getId(), vehicle.getBrand(), vehicle.getVehicleName(), position, spec);
    }

    public TireRecommendationResponse getRecommendationBySpec(Integer specId, TirePosition position) {
        if (specId == null) {
            throw new RuntimeException("Please choose a vehicle tire spec before scanning the tire.");
        }
        validatePosition(position);

        VehicleTireSpec spec = tireSpecRepository.findById(specId)
                .orElseThrow(() -> new RuntimeException("Selected tire specification was not found."));

        return buildRecommendation(spec.getId(), spec.getBrand(), spec.getVehicleName(), position, spec);
    }

    private TireRecommendationResponse buildRecommendation(
            Integer referenceId,
            String brand,
            String vehicleName,
            TirePosition position,
            VehicleTireSpec spec
    ) {
        String rawSize = position == TirePosition.FRONT ? spec.getFrontTireSize() : spec.getRearTireSize();
        String tireSize = extractCoreTireSize(rawSize);
        List<SparePart> matches = sparePartRepository.searchCatalogText(tireCategoryId, tireSize);
        if (matches.isEmpty()) {
            matches = sparePartRepository.searchCatalogTextWithoutCategory(tireSize);
        }

        List<TireQuoteOptionResponse> options = matches.stream()
                .filter(part -> catalogText(part).contains(tireSize.toLowerCase(Locale.ROOT)))
                .sorted(Comparator.comparing(part -> part.getPrice() == null ? BigDecimal.ZERO : part.getPrice()))
                .limit(MAX_RECOMMENDATION_OPTIONS)
                .map(part -> toQuoteOption(part, tireSize))
                .toList();

        return new TireRecommendationResponse(
                referenceId,
                brand,
                vehicleName,
                position,
                tireSize,
                TIRE_REPLACEMENT_LABOR_MIN,
                TIRE_REPLACEMENT_LABOR_MAX,
                "This is an estimated quote based on the selected vehicle spec and current catalog data. "
                        + "The branch will confirm condition, stock, and final price before replacement.",
                options
        );
    }

    private void validatePosition(TirePosition position) {
        if (position == null) {
            throw new RuntimeException("Please choose front tire or rear tire.");
        }
    }

    private VehicleTireSpec findTireSpec(String brand, String vehicleName, String vehicleType, Integer engineCapacity) {
        List<VehicleTireSpec> exactMatches = tireSpecRepository.findBestMatches(
                brand,
                vehicleName,
                vehicleType,
                engineCapacity
        );
        if (!exactMatches.isEmpty()) {
            return exactMatches.get(0);
        }

        return tireSpecRepository.findBestMatchesByModel(
                        brand,
                        vehicleName,
                        vehicleType,
                        engineCapacity
                )
                .stream()
                .findFirst()
                .orElseThrow(() -> new RuntimeException(
                        "No tire specification found for " + brand + " " + vehicleName
                                + ". Please add data to vehicle_tire_specs."
                ));
    }

    private TireQuoteOptionResponse toQuoteOption(SparePart part, String tireSize) {
        BigDecimal price = part.getPrice() == null ? BigDecimal.ZERO : part.getPrice();
        Integer categoryId = part.getCategory() == null ? null : part.getCategory().getId();
        return new TireQuoteOptionResponse(
                part.getId(),
                part.getName(),
                price,
                part.getDescription(),
                part.getImageUrl(),
                categoryId,
                tireSize,
                TIRE_REPLACEMENT_LABOR_MIN,
                TIRE_REPLACEMENT_LABOR_MAX,
                price.add(TIRE_REPLACEMENT_LABOR_MIN),
                price.add(TIRE_REPLACEMENT_LABOR_MAX),
                SIZE_MATCH_CONFIDENCE,
                "Matched size " + tireSize + " in the product name or description. "
                        + "A branch should confirm fit before replacement."
        );
    }

    private String extractCoreTireSize(String value) {
        String input = trimToEmpty(value);
        Matcher matcher = TIRE_SIZE_PATTERN.matcher(input);
        if (matcher.find()) {
            return matcher.group(1);
        }
        throw new RuntimeException("Tire specification format is invalid. Please check vehicle_tire_specs.");
    }

    private String catalogText(SparePart part) {
        return (trimToEmpty(part.getName()) + " " + trimToEmpty(part.getDescription())).toLowerCase(Locale.ROOT);
    }

    private String trimToEmpty(String value) {
        return value == null ? "" : value.trim();
    }
}
