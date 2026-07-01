package com.carebike.backend.features.ai.dto;

import java.util.List;

/**
 * DTO đại diện cho toàn bộ cấu trúc response trả về từ Gemini 1.5 Flash API.
 * Cấu trúc JSON tương ứng:
 * {
 *   "candidates": [
 *     {
 *       "content": {
 *         "parts": [
 *           { "text": "..." }
 *         ]
 *       }
 *     }
 *   ]
 * }
 */
public class GeminiResponse {

    private List<Candidate> candidates;

    // === Constructor ===

    public GeminiResponse() {
    }

    public GeminiResponse(List<Candidate> candidates) {
        this.candidates = candidates;
    }

    // === Getter / Setter ===

    public List<Candidate> getCandidates() {
        return candidates;
    }

    public void setCandidates(List<Candidate> candidates) {
        this.candidates = candidates;
    }

    /**
     * Phương thức tiện ích: Trích xuất nội dung text từ candidate đầu tiên.
     * Trả về chuỗi rỗng nếu response không chứa dữ liệu hợp lệ.
     *
     * @return Nội dung text phản hồi từ AI, hoặc chuỗi rỗng nếu không có kết quả
     */
    public String extractTextResponse() {
        if (candidates != null && !candidates.isEmpty()) {
            Candidate firstCandidate = candidates.get(0);
            if (firstCandidate.getContent() != null
                    && firstCandidate.getContent().getParts() != null
                    && !firstCandidate.getContent().getParts().isEmpty()) {
                return firstCandidate.getContent().getParts().get(0).getText();
            }
        }
        return "";
    }
}
