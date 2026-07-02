package com.carebike.backend.config;

import com.carebike.backend.security.JwtAuthenticationFilter;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.HttpMethod;
import org.springframework.security.config.annotation.method.configuration.EnableMethodSecurity;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter;

@Configuration
@EnableMethodSecurity
public class SecurityConfig {

    private final JwtAuthenticationFilter jwtAuthenticationFilter;

    public SecurityConfig(JwtAuthenticationFilter jwtAuthenticationFilter) {
        this.jwtAuthenticationFilter = jwtAuthenticationFilter;
    }

    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
        http
                .cors(org.springframework.security.config.Customizer.withDefaults())
                .csrf(csrf -> csrf.disable()) // Tắt CSRF là bắt buộc với Mobile App/React
                .sessionManagement(session -> session.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
                .authorizeHttpRequests(auth -> auth
                        // 1. CÁC API CÔNG KHAI: Ai cũng có thể gọi mà không cần kiểm tra Token
                        // Cho phép gọi OPTIONS để tránh lỗi CORS Preflight
                        .requestMatchers(HttpMethod.OPTIONS, "/**").permitAll()
                        // Mở khóa Auth, Web-socket và thư mục hiển thị Hình ảnh
                        .requestMatchers("/api/auth/**", "/error", "/ws/**", "/images/**").permitAll()

                        // 2. PHÂN QUYỀN THEO NGHIỆP VỤ ROLE
                        // Chỉ Admin mới được vào các API quản trị
                        .requestMatchers("/api/admin/**").hasRole("ADMIN")

                        // Branch và Admin được quyền quản lý chi nhánh
                        .requestMatchers("/api/branch/**").hasAnyRole("ADMIN", "BRANCH")

                        // Customer có thể đặt lịch, Branch/Admin có thể xem lịch
                        .requestMatchers("/api/appointments/**").hasAnyRole("CUSTOMER", "BRANCH", "ADMIN")

                        // AI Tư vấn bảo dưỡng — cho phép tất cả người dùng đã xác thực
                        .requestMatchers("/api/ai/**").hasAnyRole("CUSTOMER", "BRANCH", "ADMIN")

                        // Tất cả các request khác phải có Token hợp lệ
                        .anyRequest().authenticated()
                );

        http.addFilterBefore(jwtAuthenticationFilter, UsernamePasswordAuthenticationFilter.class);
        return http.build();
    }
}