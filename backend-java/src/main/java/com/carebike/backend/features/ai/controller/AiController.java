package com.carebike.backend.features.ai.controller;

import com.carebike.backend.features.ai.dto.AiConsultRequest;
import com.carebike.backend.features.ai.dto.AiConsultResponse;
import com.carebike.backend.features.ai.service.GeminiApiService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

/**
 * Controller xử lý các yêu cầu liên quan đến tính năng AI Tư vấn Bảo dưỡng.
 * Cung cấp endpoint RESTful cho phép khách hàng gửi câu hỏi
 * và nhận phản hồi tư vấn thông minh từ mô hình Gemini AI.
 */
@RestController
@RequestMapping("/api/ai")
@CrossOrigin(origins = "*")
public class AiController {

    private final GeminiApiService geminiApiService;

    /**
     * Constructor injection — nhận GeminiApiService từ Spring IoC container.
     *
     * @param geminiApiService Service xử lý logic gọi Gemini API
     */
    public AiController(GeminiApiService geminiApiService) {
        this.geminiApiService = geminiApiService;
    }

    /**
     * POST /api/ai/consult
     * Endpoint tiếp nhận yêu cầu tư vấn bảo dưỡng từ khách hàng.
     * Hệ thống sẽ truy xuất lịch sử bảo dưỡng, xây dựng prompt có bối cảnh,
     * gọi Gemini AI và trả về câu trả lời tư vấn chuyên nghiệp.
     *
     * @param request DTO chứa customerId và message từ phía khách hàng
     * @return ResponseEntity chứa câu trả lời tư vấn của AI
     */
    @PostMapping("/consult")
    public ResponseEntity<AiConsultResponse> consult(@RequestBody AiConsultRequest request) {
        // Gọi service để xử lý logic tư vấn AI có bối cảnh lịch sử bảo dưỡng
        String aiReply = geminiApiService.getAiConsultation(
                request.getCustomerId(),
                request.getMessage()
        );

        // Đóng gói phản hồi vào DTO response và trả về cho client
        return ResponseEntity.ok(new AiConsultResponse(aiReply));
    }
}
