package com.carebike.backend.features.ai.dto;

import java.util.List;

/**
 * DTO đại diện cho đối tượng "content" trong cấu trúc JSON của Gemini API.
 * Mỗi Content chứa một danh sách các Part (phần nội dung).
 */
public class Content {

    private List<Part> parts;

    // === Constructor ===

    public Content() {
    }

    public Content(List<Part> parts) {
        this.parts = parts;
    }

    // === Getter / Setter ===

    public List<Part> getParts() {
        return parts;
    }

    public void setParts(List<Part> parts) {
        this.parts = parts;
    }
}
