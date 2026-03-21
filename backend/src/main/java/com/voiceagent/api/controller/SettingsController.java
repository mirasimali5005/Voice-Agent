package com.voiceagent.api.controller;

import com.voiceagent.api.dto.SettingsDTO;
import com.voiceagent.api.service.SettingsService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/api/settings")
public class SettingsController {

    private final SettingsService settingsService;

    public SettingsController(SettingsService settingsService) {
        this.settingsService = settingsService;
    }

    /**
     * Fetch all settings for a user as key/value map.
     */
    @GetMapping
    public ResponseEntity<Map<String, String>> getSettings(@RequestParam UUID userId) {
        Map<String, String> settings = settingsService.getSettings(userId);
        return ResponseEntity.ok(settings);
    }

    /**
     * Upsert a setting (create or update).
     */
    @PostMapping
    public ResponseEntity<SettingsDTO> upsertSetting(@RequestBody SettingsDTO dto) {
        SettingsDTO saved = settingsService.upsertSetting(dto);
        return ResponseEntity.ok(saved);
    }
}
