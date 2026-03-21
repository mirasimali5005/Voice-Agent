package com.voiceagent.api.service;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.stereotype.Service;
import org.springframework.web.reactive.function.client.WebClient;
import org.springframework.web.reactive.function.client.WebClientResponseException;

import java.time.LocalDate;
import java.util.List;
import java.util.Map;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.concurrent.atomic.AtomicReference;

@Service
public class CloudflareAIService {

    private static final Logger log = LoggerFactory.getLogger(CloudflareAIService.class);
    private static final int DAILY_RATE_LIMIT = 9000;
    private static final String MODEL = "@cf/meta/llama-3.1-8b-instruct";

    private final WebClient webClient;
    private final AtomicInteger dailyRequestCount = new AtomicInteger(0);
    private final AtomicReference<LocalDate> currentDay = new AtomicReference<>(LocalDate.now());

    public CloudflareAIService(WebClient cloudflareWebClient) {
        this.webClient = cloudflareWebClient;
    }

    /**
     * Send pattern rules and raw corrections to Cloudflare Workers AI for refinement.
     * If Cloudflare is unavailable or rate-limited, returns patternRules as-is.
     */
    public String refineRules(String patternRules, String rawCorrections) {
        if (!checkAndIncrementRateLimit()) {
            log.warn("Cloudflare daily rate limit reached, returning pattern rules as-is");
            return patternRules;
        }

        String prompt = buildRefinePrompt(patternRules, rawCorrections);

        try {
            return callCloudflareAI(prompt);
        } catch (Exception e) {
            log.error("Cloudflare AI refinement failed, returning pattern rules as-is", e);
            return patternRules;
        }
    }

    /**
     * Ask Cloudflare AI to compare two rule sets and pick the better one.
     * If Cloudflare is unavailable, returns patternRules.
     */
    public String compareRuleSets(String patternRules, String refinedRules) {
        if (!checkAndIncrementRateLimit()) {
            log.warn("Cloudflare daily rate limit reached, returning pattern rules");
            return patternRules;
        }

        String prompt = buildComparePrompt(patternRules, refinedRules);

        try {
            return callCloudflareAI(prompt);
        } catch (Exception e) {
            log.error("Cloudflare AI comparison failed, returning pattern rules", e);
            return patternRules;
        }
    }

    private String callCloudflareAI(String prompt) {
        Map<String, Object> requestBody = Map.of(
                "messages", List.of(
                        Map.of("role", "system", "content",
                                "You are a text correction rule optimizer. Respond only with the optimized rules, no explanation."),
                        Map.of("role", "user", "content", prompt)
                )
        );

        try {
            Map<String, Object> response = webClient
                    .post()
                    .uri("/" + MODEL)
                    .bodyValue(requestBody)
                    .retrieve()
                    .bodyToMono(Map.class)
                    .block();

            if (response == null) {
                throw new RuntimeException("Empty response from Cloudflare AI");
            }

            // Cloudflare Workers AI response format: { "result": { "response": "..." } }
            Object result = response.get("result");
            if (result instanceof Map) {
                Object responseText = ((Map<?, ?>) result).get("response");
                if (responseText != null) {
                    return responseText.toString();
                }
            }

            throw new RuntimeException("Unexpected response format from Cloudflare AI");
        } catch (WebClientResponseException e) {
            log.error("Cloudflare API error: {} {}", e.getStatusCode(), e.getResponseBodyAsString());
            throw e;
        }
    }

    private boolean checkAndIncrementRateLimit() {
        LocalDate today = LocalDate.now();
        LocalDate tracked = currentDay.get();

        // Reset counter on new day
        if (!today.equals(tracked)) {
            if (currentDay.compareAndSet(tracked, today)) {
                dailyRequestCount.set(0);
            }
        }

        int count = dailyRequestCount.incrementAndGet();
        if (count > DAILY_RATE_LIMIT) {
            dailyRequestCount.decrementAndGet();
            return false;
        }
        return true;
    }

    private String buildRefinePrompt(String patternRules, String rawCorrections) {
        return "I have these auto-generated correction rules based on user patterns:\n\n" +
               patternRules +
               "\n\nAnd these raw corrections from the user:\n\n" +
               rawCorrections +
               "\n\nPlease refine and optimize these rules. " +
               "Merge duplicates, improve patterns, and ensure consistency. " +
               "Output the refined rules in the same format: " +
               "[REPLACEMENTS], [STYLE], and [FORMATTING] sections. " +
               "Keep it under 50 lines total.";
    }

    private String buildComparePrompt(String patternRules, String refinedRules) {
        return "Compare these two sets of text correction rules and return ONLY the better set.\n\n" +
               "SET A (pattern-based):\n" + patternRules +
               "\n\nSET B (AI-refined):\n" + refinedRules +
               "\n\nChoose the set that is more accurate, comprehensive, and concise. " +
               "Return only the chosen rule set, nothing else.";
    }
}
