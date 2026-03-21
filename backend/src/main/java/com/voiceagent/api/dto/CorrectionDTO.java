package com.voiceagent.api.dto;

import java.time.OffsetDateTime;
import java.util.UUID;

public class CorrectionDTO {

    private UUID id;
    private UUID userId;
    private String beforeText;
    private String afterText;
    private String context;
    private String mode;
    private Integer count;
    private Boolean autoRule;
    private OffsetDateTime createdAt;

    public CorrectionDTO() {}

    public UUID getId() {
        return id;
    }

    public void setId(UUID id) {
        this.id = id;
    }

    public UUID getUserId() {
        return userId;
    }

    public void setUserId(UUID userId) {
        this.userId = userId;
    }

    public String getBeforeText() {
        return beforeText;
    }

    public void setBeforeText(String beforeText) {
        this.beforeText = beforeText;
    }

    public String getAfterText() {
        return afterText;
    }

    public void setAfterText(String afterText) {
        this.afterText = afterText;
    }

    public String getContext() {
        return context;
    }

    public void setContext(String context) {
        this.context = context;
    }

    public String getMode() {
        return mode;
    }

    public void setMode(String mode) {
        this.mode = mode;
    }

    public Integer getCount() {
        return count;
    }

    public void setCount(Integer count) {
        this.count = count;
    }

    public Boolean getAutoRule() {
        return autoRule;
    }

    public void setAutoRule(Boolean autoRule) {
        this.autoRule = autoRule;
    }

    public OffsetDateTime getCreatedAt() {
        return createdAt;
    }

    public void setCreatedAt(OffsetDateTime createdAt) {
        this.createdAt = createdAt;
    }
}
