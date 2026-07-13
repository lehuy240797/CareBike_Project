package com.carebike.backend.features.notification.service;

import com.carebike.backend.features.auth.entity.User;
import com.carebike.backend.features.notification.entity.DeviceToken;
import com.carebike.backend.features.notification.repository.DeviceTokenRepository;
import com.google.firebase.messaging.AndroidConfig;
import com.google.firebase.messaging.AndroidNotification;
import com.google.firebase.messaging.FirebaseMessaging;
import com.google.firebase.messaging.FirebaseMessagingException;
import com.google.firebase.messaging.Message;
import com.google.firebase.messaging.MessagingErrorCode;
import com.google.firebase.messaging.Notification;
import org.springframework.stereotype.Service;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

@Service
public class FcmService {

    private static final String HIGH_IMPORTANCE_CHANNEL_ID = "carebike_high_importance";

    private final DeviceTokenRepository deviceTokenRepository;

    public FcmService(DeviceTokenRepository deviceTokenRepository) {
        this.deviceTokenRepository = deviceTokenRepository;
    }

    public void sendToUser(User user, String title, String body, Map<String, String> data) {
        if (user == null || user.getId() == null) {
            return;
        }

        List<DeviceToken> tokens = deviceTokenRepository.findByUserIdAndEnabledTrue(user.getId());
        for (DeviceToken token : tokens) {
            sendToToken(token, title, body, data);
        }
    }

    private void sendToToken(DeviceToken deviceToken, String title, String body, Map<String, String> data) {
        try {
            Message message = Message.builder()
                    .setToken(deviceToken.getFcmToken())
                    .setNotification(Notification.builder()
                            .setTitle(title)
                            .setBody(body)
                            .build())
                    .putAllData(sanitizeData(data))
                    .setAndroidConfig(AndroidConfig.builder()
                            .setPriority(AndroidConfig.Priority.HIGH)
                            .setNotification(AndroidNotification.builder()
                                    .setChannelId(HIGH_IMPORTANCE_CHANNEL_ID)
                                    .setPriority(AndroidNotification.Priority.HIGH)
                                    .setDefaultSound(true)
                                    .setDefaultVibrateTimings(true)
                                    .build())
                            .build())
                    .build();

            FirebaseMessaging.getInstance().send(message);
        } catch (FirebaseMessagingException ex) {
            if (isInvalidToken(ex)) {
                deviceToken.setEnabled(false);
                deviceTokenRepository.save(deviceToken);
            }
        } catch (Exception ignored) {
            // Notification delivery must not break appointment/rescue status updates.
        }
    }

    private boolean isInvalidToken(FirebaseMessagingException ex) {
        MessagingErrorCode code = ex.getMessagingErrorCode();
        return code == MessagingErrorCode.UNREGISTERED || code == MessagingErrorCode.INVALID_ARGUMENT;
    }

    private Map<String, String> sanitizeData(Map<String, String> data) {
        Map<String, String> clean = new HashMap<>();
        if (data == null) {
            return clean;
        }
        data.forEach((key, value) -> {
            if (key != null && value != null) {
                clean.put(key, value);
            }
        });
        return clean;
    }
}
