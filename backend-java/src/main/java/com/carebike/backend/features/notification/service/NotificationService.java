package com.carebike.backend.features.notification.service;

import com.carebike.backend.features.appointment.entity.Appointment;
import com.carebike.backend.features.auth.entity.User;
import com.carebike.backend.features.branch.entity.Branch;
import com.carebike.backend.features.notification.dto.DeviceTokenRequest;
import com.carebike.backend.features.notification.entity.DeviceToken;
import com.carebike.backend.features.notification.repository.DeviceTokenRepository;
import com.carebike.backend.features.rescue.entity.Rescue;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.HashMap;
import java.util.Map;

@Service
public class NotificationService {

    private static final String DEFAULT_PLATFORM = "ANDROID";

    private final DeviceTokenRepository deviceTokenRepository;
    private final FcmService fcmService;

    public NotificationService(DeviceTokenRepository deviceTokenRepository, FcmService fcmService) {
        this.deviceTokenRepository = deviceTokenRepository;
        this.fcmService = fcmService;
    }

    @Transactional
    public void registerDeviceToken(User user, DeviceTokenRequest request) {
        if (user == null || request == null || isBlank(request.getToken())) {
            throw new RuntimeException("FCM token không hợp lệ.");
        }

        DeviceToken deviceToken = deviceTokenRepository.findFirstByFcmToken(request.getToken())
                .orElseGet(DeviceToken::new);
        deviceToken.setUser(user);
        deviceToken.setFcmToken(request.getToken());
        deviceToken.setPlatform(normalizePlatform(request.getPlatform()));
        deviceToken.setEnabled(true);
        deviceToken.setLastSeenAt(Instant.now());
        deviceTokenRepository.save(deviceToken);
    }

    @Transactional
    public void unregisterDeviceToken(User user, DeviceTokenRequest request) {
        if (user == null || request == null || isBlank(request.getToken())) {
            return;
        }
        deviceTokenRepository.deleteByUserIdAndFcmToken(user.getId(), request.getToken());
    }

    public void notifyAppointmentCreated(Appointment appointment) {
        if (appointment == null) {
            return;
        }
        Branch branch = appointment.getBranch();
        User manager = branch != null ? branch.getManager() : null;
        String customerName = displayName(appointment.getCustomer(), "Khách hàng");

        fcmService.sendToUser(
                manager,
                "Lịch hẹn mới",
                customerName + " vừa đặt lịch sửa chữa tại chi nhánh.",
                appointmentData("NEW_APPOINTMENT", appointment)
        );
    }

    public void notifyAppointmentCancelledByCustomer(Appointment appointment) {
        if (appointment == null) {
            return;
        }
        Branch branch = appointment.getBranch();
        User manager = branch != null ? branch.getManager() : null;
        String customerName = displayName(appointment.getCustomer(), "Khách hàng");

        fcmService.sendToUser(
                manager,
                "Khách hàng đã hủy lịch hẹn",
                customerName + " đã hủy lịch hẹn sửa chữa.",
                appointmentData("APPOINTMENT_CANCELLED_BY_CUSTOMER", appointment)
        );
    }

    public void notifyAppointmentStatusChanged(Appointment appointment) {
        if (appointment == null || appointment.getCustomer() == null) {
            return;
        }

        String status = appointment.getStatus();
        String branchName = appointment.getBranch() != null ? appointment.getBranch().getName() : "CareBike";
        String title = switch (status) {
            case "CONFIRMED" -> "Lịch hẹn đã được xác nhận";
            case "COMPLETED" -> "Xe đã bảo dưỡng xong";
            case "CANCELLED" -> "Lịch hẹn đã bị hủy";
            default -> "Cập nhật lịch hẹn";
        };
        String body = switch (status) {
            case "CONFIRMED" -> branchName + " đã xác nhận lịch hẹn của bạn.";
            case "COMPLETED" -> "Dịch vụ tại " + branchName + " đã hoàn tất.";
            case "CANCELLED" -> "Lịch hẹn tại " + branchName + " đã bị hủy.";
            default -> "Lịch hẹn của bạn vừa được cập nhật trạng thái.";
        };

        fcmService.sendToUser(
                appointment.getCustomer(),
                title,
                body,
                appointmentData("APPOINTMENT_STATUS", appointment)
        );
    }

    public void notifyRescueCreated(Rescue rescue) {
        if (rescue == null) {
            return;
        }
        Branch branch = rescue.getBranch();
        User manager = branch != null ? branch.getManager() : null;
        String customerName = displayName(rescue.getCustomer(), "Khách hàng");

        fcmService.sendToUser(
                manager,
                "Yêu cầu cứu hộ khẩn cấp",
                customerName + " vừa gửi yêu cầu cứu hộ gần chi nhánh.",
                rescueData("NEW_RESCUE", rescue)
        );
    }

    public void notifyRescueStatusChanged(Rescue rescue) {
        if (rescue == null || rescue.getCustomer() == null) {
            return;
        }

        String status = rescue.getStatus();
        String branchName = rescue.getBranch() != null ? rescue.getBranch().getName() : "CareBike";
        String title = switch (status) {
            case "ACCEPTED" -> "Chi nhánh đã nhận cứu hộ";
            case "COMPLETED" -> "Ca cứu hộ đã hoàn tất";
            case "CANCELLED" -> "Ca cứu hộ đã bị hủy";
            default -> "Cập nhật cứu hộ";
        };
        String body = switch (status) {
            case "ACCEPTED" -> branchName + " đã tiếp nhận và đang đến hỗ trợ bạn.";
            case "COMPLETED" -> "Ca cứu hộ của bạn đã được hoàn tất.";
            case "CANCELLED" -> "Yêu cầu cứu hộ của bạn đã bị hủy.";
            default -> "Yêu cầu cứu hộ của bạn vừa được cập nhật trạng thái.";
        };

        fcmService.sendToUser(
                rescue.getCustomer(),
                title,
                body,
                rescueData("RESCUE_STATUS", rescue)
        );
    }

    private Map<String, String> appointmentData(String type, Appointment appointment) {
        Map<String, String> data = baseData(type, "appointments", appointment.getStatus());
        data.put("targetId", String.valueOf(appointment.getId()));
        if (appointment.getBranch() != null) {
            data.put("branchId", String.valueOf(appointment.getBranch().getId()));
        }
        return data;
    }

    private Map<String, String> rescueData(String type, Rescue rescue) {
        Map<String, String> data = baseData(type, "rescues", rescue.getStatus());
        data.put("targetId", String.valueOf(rescue.getId()));
        if (rescue.getBranch() != null) {
            data.put("branchId", String.valueOf(rescue.getBranch().getId()));
        }
        return data;
    }

    private Map<String, String> baseData(String type, String route, String status) {
        Map<String, String> data = new HashMap<>();
        data.put("type", type);
        data.put("route", route);
        data.put("status", status != null ? status : "");
        return data;
    }

    private String normalizePlatform(String platform) {
        if (isBlank(platform)) {
            return DEFAULT_PLATFORM;
        }
        return platform.trim().toUpperCase();
    }

    private String displayName(User user, String fallback) {
        if (user == null || isBlank(user.getFullName())) {
            return fallback;
        }
        return user.getFullName();
    }

    private boolean isBlank(String value) {
        return value == null || value.trim().isEmpty();
    }
}
