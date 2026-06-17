package com.carebike.backend.security;

import com.carebike.backend.features.auth.entity.User;
import com.carebike.backend.features.auth.repository.UserRepository;
import com.google.firebase.auth.FirebaseAuth;
import com.google.firebase.auth.FirebaseToken;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.web.authentication.WebAuthenticationDetailsSource;
import org.springframework.stereotype.Component;
import org.springframework.util.StringUtils;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.util.Collections;
import java.util.Optional;

@Component
public class JwtAuthenticationFilter extends OncePerRequestFilter {

    private final UserRepository userRepository;

    public JwtAuthenticationFilter(UserRepository userRepository) {
        this.userRepository = userRepository;
    }

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain filterChain)
            throws ServletException, IOException {
        try {
            String jwt = getJwtFromRequest(request);

            if (StringUtils.hasText(jwt)) {
                // 1. Firebase Admin SDK kiểm tra tính hợp lệ của Token
                FirebaseToken decodedToken = FirebaseAuth.getInstance().verifyIdToken(jwt);
                String firebaseUid = decodedToken.getUid();
                
                // 2. Gắn UID vào request để API Register có thể lấy ra sử dụng
                request.setAttribute("firebaseUid", firebaseUid);
                
                // THÊM DÒNG NÀY: Gắn toàn bộ Token vào request để API Login (Google) có thể lấy Email/Tên tạo tài khoản
                request.setAttribute("firebaseToken", decodedToken);

                // ====================================================================
                // LOGIC CÁCH 1: BỎ QUA DATABASE CHO CÁC API AUTHENTICATION
                // ====================================================================
                String requestURI = request.getRequestURI();
                if (requestURI.startsWith("/api/auth/")) {
                    // Đã lấy được UID xong. Vì đây là API đăng ký/đăng nhập nên nhường quyền
                    // cho Controller tự xử lý tiếp. Không query DB tìm User để tránh lỗi 403.
                    filterChain.doFilter(request, response);
                    return; 
                }
                // ====================================================================

                // 3. NẾU LÀ CÁC API KHÁC (như xem danh sách, đặt lịch...): 
                // Tìm khách hàng trong Database MySQL để cấp quyền (Role)
                Optional<User> userOptional = userRepository.findByFirebaseUid(firebaseUid);

                if (userOptional.isPresent()) {
                    User user = userOptional.get();
                    
                    // Cấp quyền truy cập theo Role (CUSTOMER, ADMIN, BRANCH)
                    SimpleGrantedAuthority authority = new SimpleGrantedAuthority("ROLE_" + user.getRole().getRoleName());
                    UsernamePasswordAuthenticationToken authentication = new UsernamePasswordAuthenticationToken(
                            user, null, Collections.singletonList(authority));
                    authentication.setDetails(new WebAuthenticationDetailsSource().buildDetails(request));

                    // Xác nhận User hợp lệ và cho phép request đi tiếp vào Controller
                    SecurityContextHolder.getContext().setAuthentication(authentication);
                }
            }
        } catch (Exception ex) {
            logger.error("Token Firebase không hợp lệ hoặc đã hết hạn: " + ex.getMessage());
        }

        filterChain.doFilter(request, response);
    }

    // Hàm lấy token từ Header Authorization
    private String getJwtFromRequest(HttpServletRequest request) {
        String bearerToken = request.getHeader("Authorization");
        if (StringUtils.hasText(bearerToken) && bearerToken.startsWith("Bearer ")) {
            return bearerToken.substring(7);
        }
        return null;
    }
}