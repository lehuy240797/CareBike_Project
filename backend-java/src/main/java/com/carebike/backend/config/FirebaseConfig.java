package com.carebike.backend.config;

import com.google.auth.oauth2.GoogleCredentials;
import com.google.firebase.FirebaseApp;
import com.google.firebase.FirebaseOptions;
import org.springframework.context.annotation.Configuration;

import jakarta.annotation.PostConstruct;
import java.io.InputStream;

@Configuration
public class FirebaseConfig {

    @PostConstruct
    public void init() {
        try {
            // Đọc file chìa khóa từ thư mục resources
            InputStream serviceAccount = getClass().getClassLoader().getResourceAsStream("carebike-firebase-adminsdk.json");
            
            if (serviceAccount == null) {
                throw new RuntimeException("Không tìm thấy file carebike-firebase-adminsdk.json");
            }

            FirebaseOptions options = FirebaseOptions.builder()
                    .setCredentials(GoogleCredentials.fromStream(serviceAccount))
                    .build();

            // Khởi tạo Firebase nếu chưa có
            if (FirebaseApp.getApps().isEmpty()) {
                FirebaseApp.initializeApp(options);
                System.out.println("Firebase Admin SDK đã khởi động thành công!");
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
    }
}