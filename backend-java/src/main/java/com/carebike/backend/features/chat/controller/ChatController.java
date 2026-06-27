package com.carebike.backend.features.chat.controller;

import com.carebike.backend.features.chat.dto.ChatRequest;
import com.carebike.backend.features.chat.dto.ChatResponse;
import com.carebike.backend.features.chat.service.GeminiService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/chat")
@CrossOrigin(origins = "*")
public class ChatController {

    private final GeminiService geminiService;

    public ChatController(GeminiService geminiService) {
        this.geminiService = geminiService;
    }

    @PostMapping
    public ResponseEntity<ChatResponse> chat(@RequestBody ChatRequest request) {
        if (request.getCustomerId() == null) {
            return ResponseEntity.status(401).body(new ChatResponse("Vui lòng đăng nhập để sử dụng tính năng này."));
        }
        
        String reply = geminiService.chatWithFunctionCalling(request.getCustomerId(), request.getMessage());
        return ResponseEntity.ok(new ChatResponse(reply));
    }
}
