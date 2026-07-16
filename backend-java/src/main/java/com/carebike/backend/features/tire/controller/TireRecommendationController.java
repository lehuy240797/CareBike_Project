package com.carebike.backend.features.tire.controller;

import com.carebike.backend.features.tire.dto.TirePosition;
import com.carebike.backend.features.tire.dto.TireRecommendationResponse;
import com.carebike.backend.features.tire.service.TireRecommendationService;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequiredArgsConstructor
@RequestMapping("/api/tire-recommendations")
public class TireRecommendationController {

    private final TireRecommendationService tireRecommendationService;

    @GetMapping
    public TireRecommendationResponse getRecommendation(
            @RequestParam Integer vehicleId,
            @RequestParam TirePosition position
    ) {
        return tireRecommendationService.getRecommendation(vehicleId, position);
    }

    @GetMapping("/by-spec")
    public TireRecommendationResponse getRecommendationBySpec(
            @RequestParam Integer specId,
            @RequestParam TirePosition position
    ) {
        return tireRecommendationService.getRecommendationBySpec(specId, position);
    }
}
