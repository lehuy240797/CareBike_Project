package com.carebike.backend.features.notification.repository;

import com.carebike.backend.features.notification.entity.DeviceToken;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface DeviceTokenRepository extends JpaRepository<DeviceToken, Long> {
    Optional<DeviceToken> findFirstByFcmToken(String fcmToken);

    List<DeviceToken> findByUserIdAndEnabledTrue(Integer userId);

    void deleteByUserIdAndFcmToken(Integer userId, String fcmToken);
}
