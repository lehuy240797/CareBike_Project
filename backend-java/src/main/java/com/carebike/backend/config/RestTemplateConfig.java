package com.carebike.backend.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.client.RestTemplate;

/**
 * Cấu hình bean RestTemplate dùng chung cho toàn bộ ứng dụng.
 * RestTemplate được sử dụng để thực hiện các lời gọi HTTP đến API bên ngoài (ví dụ: Gemini AI).
 */
@Configuration
public class RestTemplateConfig {

    /**
     * Khởi tạo bean RestTemplate với cấu hình mặc định.
     * Bean này sẽ được inject vào các Service cần gọi API bên ngoài.
     *
     * @return Đối tượng RestTemplate sẵn sàng sử dụng
     */
    @Bean
    public RestTemplate restTemplate() {
        return new RestTemplate();
    }
}
