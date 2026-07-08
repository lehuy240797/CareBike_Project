package com.carebike.backend.features.ai.dto;

import lombok.Data;

/**
 * DTO đại diện cho request body của endpoint tư vấn AI.
 * Chứa mã khách hàng và nội dung câu hỏi mà khách hàng gửi lên.
 */
@Data
public class AiConsultRequest {

    /** Mã định danh của khách hàng trong hệ thống */
    private Integer customerId;

    /** Nội dung câu hỏi hoặc mô tả vấn đề từ phía khách hàng */
    private String message;
}
