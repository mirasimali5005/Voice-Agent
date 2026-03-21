package com.voiceagent.api.service;

import com.voiceagent.api.dto.SettingsDTO;
import com.voiceagent.api.model.Setting;
import com.voiceagent.api.model.User;
import com.voiceagent.api.repository.SettingRepository;
import com.voiceagent.api.repository.UserRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;

@Service
public class SettingsService {

    private final SettingRepository settingRepository;
    private final UserRepository userRepository;

    public SettingsService(SettingRepository settingRepository, UserRepository userRepository) {
        this.settingRepository = settingRepository;
        this.userRepository = userRepository;
    }

    public Map<String, String> getSettings(UUID userId) {
        List<Setting> settings = settingRepository.findByUserId(userId);
        Map<String, String> map = new LinkedHashMap<>();
        for (Setting s : settings) {
            map.put(s.getKey(), s.getValue());
        }
        return map;
    }

    @Transactional
    public SettingsDTO upsertSetting(SettingsDTO dto) {
        User user = userRepository.findById(dto.getUserId())
                .orElseThrow(() -> new IllegalArgumentException("User not found: " + dto.getUserId()));

        Optional<Setting> existing = settingRepository.findByUserIdAndKey(dto.getUserId(), dto.getKey());

        Setting setting;
        if (existing.isPresent()) {
            setting = existing.get();
            setting.setValue(dto.getValue());
        } else {
            setting = new Setting();
            setting.setUser(user);
            setting.setKey(dto.getKey());
            setting.setValue(dto.getValue());
        }

        Setting saved = settingRepository.save(setting);
        return toDTO(saved);
    }

    private SettingsDTO toDTO(Setting s) {
        SettingsDTO dto = new SettingsDTO();
        dto.setId(s.getId());
        dto.setUserId(s.getUser().getId());
        dto.setKey(s.getKey());
        dto.setValue(s.getValue());
        return dto;
    }
}
