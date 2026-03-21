package com.voiceagent.api.config;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.reactive.function.client.WebClient;

@Configuration
public class CloudflareConfig {

    @Value("${cloudflare.account-id}")
    private String accountId;

    @Value("${cloudflare.api-token}")
    private String apiToken;

    @Value("${cloudflare.base-url}")
    private String baseUrl;

    @Bean
    public WebClient cloudflareWebClient() {
        String fullBaseUrl = baseUrl + "/" + accountId + "/ai/run";
        return WebClient.builder()
                .baseUrl(fullBaseUrl)
                .defaultHeader("Authorization", "Bearer " + apiToken)
                .defaultHeader("Content-Type", "application/json")
                .build();
    }

    public String getAccountId() {
        return accountId;
    }

    public String getApiToken() {
        return apiToken;
    }

    public String getBaseUrl() {
        return baseUrl;
    }
}
