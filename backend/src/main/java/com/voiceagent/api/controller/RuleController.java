package com.voiceagent.api.controller;

import com.voiceagent.api.dto.RuleCompareRequest;
import com.voiceagent.api.model.Rule;
import com.voiceagent.api.service.CloudflareAIService;
import com.voiceagent.api.service.PatternMatchingService;
import com.voiceagent.api.service.RuleCompressionService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/api/rules")
public class RuleController {

    private final RuleCompressionService ruleCompressionService;
    private final PatternMatchingService patternMatchingService;
    private final CloudflareAIService cloudflareAIService;

    public RuleController(RuleCompressionService ruleCompressionService,
                          PatternMatchingService patternMatchingService,
                          CloudflareAIService cloudflareAIService) {
        this.ruleCompressionService = ruleCompressionService;
        this.patternMatchingService = patternMatchingService;
        this.cloudflareAIService = cloudflareAIService;
    }

    /**
     * Fetch compressed rules as a text string for prompt injection.
     */
    @GetMapping
    public ResponseEntity<Map<String, String>> getRules(@RequestParam UUID userId) {
        String compressedRules = ruleCompressionService.compressRules(userId);
        return ResponseEntity.ok(Map.of("rules", compressedRules));
    }

    /**
     * Trigger pattern matching + AI refinement, return updated compressed rules.
     */
    @PostMapping("/refresh")
    public ResponseEntity<Map<String, String>> refreshRules(@RequestParam UUID userId) {
        // Step 1: Generate rules from correction patterns
        List<Rule> rules = patternMatchingService.generateRules(userId);

        // Step 2: Compress the generated rules
        String compressedRules = ruleCompressionService.compressRules(userId);

        // Step 3: Try AI refinement via Cloudflare
        String rawCorrectionsText = buildCorrectionsText(rules);
        String refinedRules = cloudflareAIService.refineRules(compressedRules, rawCorrectionsText);

        return ResponseEntity.ok(Map.of("rules", refinedRules));
    }

    /**
     * Compare two rule sets (pattern-based vs cloud-refined), pick the best.
     */
    @PostMapping("/compare")
    public ResponseEntity<Map<String, String>> compareRules(@RequestBody RuleCompareRequest request) {
        String bestRules = cloudflareAIService.compareRuleSets(
                request.getPatternRules(), request.getCloudRules());
        return ResponseEntity.ok(Map.of("rules", bestRules));
    }

    private String buildCorrectionsText(List<Rule> rules) {
        if (rules.isEmpty()) return "";
        StringBuilder sb = new StringBuilder();
        for (Rule rule : rules) {
            sb.append(String.format("%s -> %s (confidence: %.0f%%, reason: %s)\n",
                    rule.getPattern(), rule.getReplacement(),
                    rule.getConfidence() * 100, rule.getReasoning()));
        }
        return sb.toString();
    }
}
