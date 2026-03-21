package com.voiceagent.api.controller;

import com.voiceagent.api.dto.DictationDTO;
import com.voiceagent.api.service.DictationService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/dictations")
public class DictationController {

    private final DictationService dictationService;

    public DictationController(DictationService dictationService) {
        this.dictationService = dictationService;
    }

    /**
     * Search dictation history with optional text search (LIKE on raw_transcript and cleaned_text).
     */
    @GetMapping
    public ResponseEntity<List<DictationDTO>> getDictations(
            @RequestParam UUID userId,
            @RequestParam(required = false) String search,
            @RequestParam(defaultValue = "50") int limit) {
        List<DictationDTO> dictations = dictationService.getDictations(userId, search, limit);
        return ResponseEntity.ok(dictations);
    }

    /**
     * Store a new dictation.
     */
    @PostMapping
    public ResponseEntity<DictationDTO> storeDictation(@RequestBody DictationDTO dto) {
        DictationDTO saved = dictationService.storeDictation(dto);
        return ResponseEntity.ok(saved);
    }
}
