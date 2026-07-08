package com.carebike.backend.features.ai.dto;

/**
 * DTO đại diện cho đối tượng "part" trong cấu trúc JSON của Gemini API.
 * Mỗi Part chứa một trường "text" — là nội dung văn bản thực tế.
 */
public class Part {

    private String text;

    // === Constructor ===

    public Part() {
    }

    public Part(String text) {
        this.text = text;
    }

    // === Getter / Setter ===

    public String getText() {
        return text;
    }

    public void setText(String text) {
        this.text = text;
    }
}
