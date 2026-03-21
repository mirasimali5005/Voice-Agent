package com.voiceagent.api.repository;

import com.voiceagent.api.model.Setting;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface SettingRepository extends JpaRepository<Setting, UUID> {

    List<Setting> findByUserId(UUID userId);

    Optional<Setting> findByUserIdAndKey(UUID userId, String key);
}
