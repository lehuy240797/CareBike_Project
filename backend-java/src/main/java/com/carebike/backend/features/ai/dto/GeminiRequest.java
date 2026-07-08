package com.carebike.backend.features.ai.dto;

import java.util.List;

/**
 * DTO đại diện cho cấu trúc request gửi đến Gemini 1.5 Flash API.
 * Cấu trúc JSON tương ứng:
 * {
 *   "contents": [
 *     {
 *       "parts": [
 *         { "text": "..." }
 *       ]
 *     }
 *   ]
 * }
 */
public class GeminiRequest {

    private List<Content> contents;

    // === Constructor ===

    public GeminiRequest() {
    }

    public GeminiRequest(List<Content> contents) {
        this.contents = contents;
    }

    // === Getter / Setter ===

    public List<Content> getContents() {
        return contents;
    }

    public void setContents(List<Content> contents) {
        this.contents = contents;
    }

    /**
     * Phương thức tiện ích: Tạo nhanh một GeminiRequest từ một chuỗi prompt văn bản.
     * Giúp giảm boilerplate code khi gọi từ tầng Service.
     *
     * @param prompt Nội dung prompt cần gửi đến Gemini
     * @return Đối tượng GeminiRequest đã được cấu trúc đúng định dạng API
     */
    public static GeminiRequest fromPrompt(String prompt) {
        Part part = new Part(prompt);
        Content content = new Content(List.of(part));
        return new GeminiRequest(List.of(content));
    }
}
