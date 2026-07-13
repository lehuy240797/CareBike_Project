package com.carebike.backend.features.notification.controller;

import com.carebike.backend.features.auth.entity.User;
import com.carebike.backend.features.notification.dto.DeviceTokenRequest;
import com.carebike.backend.features.notification.service.NotificationService;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/api/notifications")
public class NotificationController {

    private final NotificationService notificationService;

    public NotificationController(NotificationService notificationService) {
        this.notificationService = notificationService;
    }

    @PostMapping("/tokens")
    public ResponseEntity<?> registerDeviceToken(@RequestBody DeviceTokenRequest request) {
        notificationService.registerDeviceToken(currentUser(), request);
        return ResponseEntity.ok(Map.of("message", "Đã đăng ký thiết bị nhận thông báo."));
    }

    @PostMapping("/tokens/remove")
    public ResponseEntity<?> removeDeviceToken(@RequestBody DeviceTokenRequest request) {
        notificationService.unregisterDeviceToken(currentUser(), request);
        return ResponseEntity.ok(Map.of("message", "Đã xóa thiết bị nhận thông báo."));
    }

    private User currentUser() {
        Object principal = SecurityContextHolder.getContext().getAuthentication().getPrincipal();
        if (principal instanceof User user) {
            return user;
        }
        throw new RuntimeException("Tài khoản chưa đăng nhập.");
    }
}
