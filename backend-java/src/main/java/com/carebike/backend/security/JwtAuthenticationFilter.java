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

            // === DEBUG LOG — xóa sau khi fix xong ===
            String uri = request.getRequestURI();
            String authHeader = request.getHeader("Authorization");
            if (uri.startsWith("/api/auth/")) {
                logger.info("[DEBUG-FILTER] URI: " + uri
                        + " | Auth header present: " + (authHeader != null)
                        + " | Starts with Bearer: " + (authHeader != null && authHeader.startsWith("Bearer "))
                        + " | JWT extracted: " + (jwt != null ? "YES (length=" + jwt.length() + ")" : "NULL"));
            }
            // === END DEBUG ===

            if (StringUtils.hasText(jwt)) {
                // 1. Firebase Admin SDK kiểm tra tính hợp lệ của Token
                FirebaseToken decodedToken = FirebaseAuth.getInstance().verifyIdToken(jwt);
                String firebaseUid = decodedToken.getUid();

                if (uri.startsWith("/api/auth/")) {
                    logger.info("[DEBUG-FILTER] Token verified OK! UID: " + firebaseUid);
                }

                // 2. Gắn UID vào request để API Register có thể lấy ra sử dụng
                request.setAttribute("firebaseUid", firebaseUid);

                // Gắn toàn bộ Token vào request để API Login (Google) có thể lấy Email/Tên
                request.setAttribute("firebaseToken", decodedToken);

                // ====================================================================
                // BỎ QUA DATABASE CHO CÁC API AUTHENTICATION
                // ====================================================================
                String requestURI = request.getRequestURI();
                if (requestURI.startsWith("/api/auth/")) {
                    filterChain.doFilter(request, response);
                    return;
                }
                // ====================================================================

                // 3. NẾU LÀ CÁC API KHÁC: Tìm User trong DB để cấp quyền (Role)
                Optional<User> userOptional = userRepository.findByFirebaseUid(firebaseUid);

                if (userOptional.isPresent()) {
                    User user = userOptional.get();
                    SimpleGrantedAuthority authority = new SimpleGrantedAuthority(
                            "ROLE_" + user.getRole().getRoleName());
                    UsernamePasswordAuthenticationToken authentication = new UsernamePasswordAuthenticationToken(
                            user, null, Collections.singletonList(authority));
                    authentication.setDetails(new WebAuthenticationDetailsSource().buildDetails(request));
                    SecurityContextHolder.getContext().setAuthentication(authentication);
                }
            }
        } catch (Exception ex) {
            logger.error("[DEBUG-FILTER] Token verification FAILED: " + ex.getClass().getName() + " - " + ex.getMessage(), ex);
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