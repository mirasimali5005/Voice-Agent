package com.voiceagent.api.service;

import com.voiceagent.api.model.Correction;
import com.voiceagent.api.model.Rule;
import com.voiceagent.api.model.User;
import com.voiceagent.api.repository.CorrectionRepository;
import com.voiceagent.api.repository.RuleRepository;
import com.voiceagent.api.repository.UserRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Service
public class PatternMatchingService {

    private static final Logger log = LoggerFactory.getLogger(PatternMatchingService.class);
    private static final int MIN_COUNT_THRESHOLD = 3;

    private final CorrectionRepository correctionRepository;
    private final RuleRepository ruleRepository;
    private final UserRepository userRepository;

    public PatternMatchingService(CorrectionRepository correctionRepository,
                                  RuleRepository ruleRepository,
                                  UserRepository userRepository) {
        this.correctionRepository = correctionRepository;
        this.ruleRepository = ruleRepository;
        this.userRepository = userRepository;
    }

    @Transactional
    public List<Rule> generateRules(UUID userId) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new IllegalArgumentException("User not found: " + userId));

        long totalCorrections = correctionRepository.countByUserId(userId);
        if (totalCorrections == 0) {
            log.info("No corrections found for user {}, skipping rule generation", userId);
            return List.of();
        }

        // Fetch corrections where count >= threshold
        List<Correction> frequentCorrections = correctionRepository
                .findByUserIdAndCountGreaterThanEqual(userId, MIN_COUNT_THRESHOLD);

        log.info("Found {} frequent corrections (count >= {}) out of {} total for user {}",
                frequentCorrections.size(), MIN_COUNT_THRESHOLD, totalCorrections, userId);

        for (Correction correction : frequentCorrections) {
            String pattern = correction.getBeforeText();
            String replacement = correction.getAfterText();

            // Check if rule already exists for this pattern+replacement
            Optional<Rule> existingRule = ruleRepository
                    .findByUserIdAndPatternAndReplacement(userId, pattern, replacement);

            float confidence = (float) correction.getCount() / totalCorrections;
            String reasoning = String.format("User corrected \"%s\" to \"%s\" %d times",
                    pattern, replacement, correction.getCount());

            if (existingRule.isPresent()) {
                Rule rule = existingRule.get();
                rule.setConfidence(confidence);
                rule.setReasoning(reasoning);
                ruleRepository.save(rule);
            } else {
                Rule rule = new Rule();
                rule.setUser(user);
                rule.setRuleType(categorizeRule(pattern, replacement));
                rule.setPattern(pattern);
                rule.setReplacement(replacement);
                rule.setContext(correction.getContext());
                rule.setMode(correction.getMode());
                rule.setConfidence(confidence);
                rule.setReasoning(reasoning);
                ruleRepository.save(rule);
            }

            // Mark correction as auto-ruled
            correction.setAutoRule(true);
            correctionRepository.save(correction);
        }

        return ruleRepository.findByUserIdOrderByConfidenceDesc(userId);
    }

    private String categorizeRule(String pattern, String replacement) {
        if (pattern == null || replacement == null) {
            return "replacement";
        }
        // If the texts differ only in case or punctuation, categorize as style/formatting
        String patternLower = pattern.toLowerCase().replaceAll("[^a-z0-9\\s]", "").trim();
        String replacementLower = replacement.toLowerCase().replaceAll("[^a-z0-9\\s]", "").trim();

        if (patternLower.equals(replacementLower)) {
            // Same words, different formatting/punctuation/case
            if (!pattern.equals(replacement) && pattern.equalsIgnoreCase(replacement)) {
                return "style";
            }
            return "formatting";
        }
        return "replacement";
    }
}
