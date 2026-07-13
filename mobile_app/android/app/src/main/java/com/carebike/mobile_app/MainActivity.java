package com.carebike.mobile_app;

import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.os.Build;
import android.os.Bundle;

import io.flutter.embedding.android.FlutterActivity;

public class MainActivity extends FlutterActivity {
    public static final String HIGH_IMPORTANCE_CHANNEL_ID = "carebike_high_importance";

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        createNotificationChannel();
    }

    private void createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return;
        }

        NotificationChannel channel = new NotificationChannel(
                HIGH_IMPORTANCE_CHANNEL_ID,
                "CareBike alerts",
                NotificationManager.IMPORTANCE_HIGH
        );
        channel.setDescription("Appointment and rescue updates");
        channel.enableVibration(true);

        NotificationManager manager = getSystemService(NotificationManager.class);
        if (manager != null) {
            manager.createNotificationChannel(channel);
        }
    }
}
