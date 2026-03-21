package com.voiceagent.api.controller;

import com.voiceagent.api.dto.CorrectionDTO;
import com.voiceagent.api.service.CorrectionService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/corrections")
public class CorrectionController {

    private final CorrectionService correctionService;

    public CorrectionController(CorrectionService correctionService) {
        this.correctionService = correctionService;
    }

    /**
     * Batch insert corrections. If same before+after+context exists for user, increments count.
     */
    @PostMapping
    public ResponseEntity<List<CorrectionDTO>> createCorrections(@RequestBody List<CorrectionDTO> corrections) {
        List<CorrectionDTO> saved = correctionService.saveCorrections(corrections);
        return ResponseEntity.ok(saved);
    }

    /**
     * Fetch corrections for a user, ordered by count descending.
     */
    @GetMapping
    public ResponseEntity<List<CorrectionDTO>> getCorrections(
            @RequestParam UUID userId,
            @RequestParam(defaultValue = "100") int limit) {
        List<CorrectionDTO> corrections = correctionService.getCorrections(userId, limit);
        return ResponseEntity.ok(corrections);
    }

    /**
     * Delete a single correction by ID.
     */
    @DeleteMapping("/{id}")
    public ResponseEntity<Void> deleteCorrection(@PathVariable UUID id) {
        correctionService.deleteCorrection(id);
        return ResponseEntity.noContent().build();
    }
}
