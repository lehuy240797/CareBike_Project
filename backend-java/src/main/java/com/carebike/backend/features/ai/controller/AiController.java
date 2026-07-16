package com.carebike.backend.features.ai.controller;

import com.carebike.backend.features.ai.dto.AiConsultRequest;
import com.carebike.backend.features.ai.dto.AiConsultResponse;
import com.carebike.backend.features.ai.service.GeminiApiService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/ai")
@CrossOrigin(origins = "*")
public class AiController {

    private final GeminiApiService geminiApiService;

    public AiController(GeminiApiService geminiApiService) {
        this.geminiApiService = geminiApiService;
    }

    @PostMapping("/consult")
    public ResponseEntity<AiConsultResponse> consult(@RequestBody AiConsultRequest request) {
        return ResponseEntity.ok(geminiApiService.getAiConsultation(request));
    }
}
