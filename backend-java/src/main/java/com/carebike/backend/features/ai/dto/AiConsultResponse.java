package com.carebike.backend.features.ai.dto;

import lombok.Data;

/**
 * DTO đại diện cho response body trả về từ endpoint tư vấn AI.
 * Chứa câu trả lời đã được xử lý từ mô hình Gemini.
 */
@Data
public class AiConsultResponse {

    /** Câu trả lời tư vấn bảo dưỡng từ AI */
    private String reply;

    // === Constructor ===

    public AiConsultResponse() {
    }

    public AiConsultResponse(String reply) {
        this.reply = reply;
    }
}
