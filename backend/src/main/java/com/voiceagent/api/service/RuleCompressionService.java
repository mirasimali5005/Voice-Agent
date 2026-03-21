package com.voiceagent.api.service;

import com.voiceagent.api.model.Rule;
import com.voiceagent.api.repository.RuleRepository;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.UUID;
import java.util.stream.Collectors;

@Service
public class RuleCompressionService {

    private static final int MAX_LINES = 50;

    private final RuleRepository ruleRepository;

    public RuleCompressionService(RuleRepository ruleRepository) {
        this.ruleRepository = ruleRepository;
    }

    /**
     * Compress all rules for a user into a text string suitable for prompt injection.
     * Format: [REPLACEMENTS] section + [STYLE] section + [FORMATTING] section.
     * Capped at 50 lines total.
     */
    public String compressRules(UUID userId) {
        List<Rule> rules = ruleRepository.findByUserIdOrderByConfidenceDesc(userId);

        if (rules.isEmpty()) {
            return "";
        }

        List<Rule> replacementRules = rules.stream()
                .filter(r -> "replacement".equals(r.getRuleType()))
                .collect(Collectors.toList());
        List<Rule> styleRules = rules.stream()
                .filter(r -> "style".equals(r.getRuleType()))
                .collect(Collectors.toList());
        List<Rule> formattingRules = rules.stream()
                .filter(r -> "formatting".equals(r.getRuleType()))
                .collect(Collectors.toList());

        StringBuilder sb = new StringBuilder();
        int linesUsed = 0;

        // [REPLACEMENTS] section
        if (!replacementRules.isEmpty() && linesUsed < MAX_LINES) {
            sb.append("[REPLACEMENTS]\n");
            linesUsed++;
            for (Rule rule : replacementRules) {
                if (linesUsed >= MAX_LINES) break;
                String line = formatRuleLine(rule);
                sb.append(line).append("\n");
                linesUsed++;
            }
            sb.append("\n");
            linesUsed++;
        }

        // [STYLE] section
        if (!styleRules.isEmpty() && linesUsed < MAX_LINES) {
            sb.append("[STYLE]\n");
            linesUsed++;
            for (Rule rule : styleRules) {
                if (linesUsed >= MAX_LINES) break;
                String line = formatRuleLine(rule);
                sb.append(line).append("\n");
                linesUsed++;
            }
            sb.append("\n");
            linesUsed++;
        }

        // [FORMATTING] section
        if (!formattingRules.isEmpty() && linesUsed < MAX_LINES) {
            sb.append("[FORMATTING]\n");
            linesUsed++;
            for (Rule rule : formattingRules) {
                if (linesUsed >= MAX_LINES) break;
                String line = formatRuleLine(rule);
                sb.append(line).append("\n");
                linesUsed++;
            }
        }

        return sb.toString().trim();
    }

    private String formatRuleLine(Rule rule) {
        String confidence = String.format("%.0f%%", rule.getConfidence() * 100);
        String contextSuffix = (rule.getContext() != null && !rule.getContext().isEmpty())
                ? " [in: " + rule.getContext() + "]"
                : "";
        return String.format("\"%s\" -> \"%s\" (%s)%s",
                rule.getPattern(), rule.getReplacement(), confidence, contextSuffix);
    }
}
