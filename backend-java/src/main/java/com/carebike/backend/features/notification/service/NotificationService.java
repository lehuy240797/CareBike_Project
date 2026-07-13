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
            throw new RuntimeException("Invalid FCM token.");
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
        String customerName = displayName(appointment.getCustomer(), "Customer");

        fcmService.sendToUser(
                manager,
                "New appointment",
                customerName + " just booked a repair appointment at your branch.",
                appointmentData("NEW_APPOINTMENT", appointment)
        );
    }

    public void notifyAppointmentCancelledByCustomer(Appointment appointment) {
        if (appointment == null) {
            return;
        }
        Branch branch = appointment.getBranch();
        User manager = branch != null ? branch.getManager() : null;
        String customerName = displayName(appointment.getCustomer(), "Customer");

        fcmService.sendToUser(
                manager,
                "Appointment cancelled by customer",
                customerName + " cancelled their repair appointment.",
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
            case "CONFIRMED" -> "Appointment confirmed";
            case "COMPLETED" -> "Bike service completed";
            case "CANCELLED" -> "Appointment cancelled";
            default -> "Appointment update";
        };
        String body = switch (status) {
            case "CONFIRMED" -> branchName + " confirmed your appointment.";
            case "COMPLETED" -> "Your service at " + branchName + " has been completed.";
            case "CANCELLED" -> "Your appointment at " + branchName + " was cancelled.";
            default -> "Your appointment status has been updated.";
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
        String customerName = displayName(rescue.getCustomer(), "Customer");

        fcmService.sendToUser(
                manager,
                "Emergency rescue request",
                customerName + " just sent a rescue request near your branch.",
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
            case "ACCEPTED" -> "Rescue accepted";
            case "COMPLETED" -> "Rescue completed";
            case "CANCELLED" -> "Rescue cancelled";
            default -> "Rescue update";
        };
        String body = switch (status) {
            case "ACCEPTED" -> branchName + " accepted your request and is on the way.";
            case "COMPLETED" -> "Your rescue request has been completed.";
            case "CANCELLED" -> "Your rescue request was cancelled.";
            default -> "Your rescue request status has been updated.";
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
