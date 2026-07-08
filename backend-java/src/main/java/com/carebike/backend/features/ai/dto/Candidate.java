package com.carebike.backend.features.ai.dto;

import java.util.List;

/**
 * DTO đại diện cho đối tượng "candidate" trong cấu trúc response của Gemini API.
 * Mỗi Candidate chứa một Content — là kết quả mà mô hình AI sinh ra.
 */
public class Candidate {

    private Content content;

    // === Constructor ===

    public Candidate() {
    }

    public Candidate(Content content) {
        this.content = content;
    }

    // === Getter / Setter ===

    public Content getContent() {
        return content;
    }

    public void setContent(Content content) {
        this.content = content;
    }
}
