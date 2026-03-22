package com.voiceagent.api.model;

import jakarta.persistence.*;

import java.time.OffsetDateTime;
import java.util.UUID;

@Entity
@Table(name = "corrections")
public class Correction {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    @Column(name = "id", updatable = false, nullable = false)
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @Column(name = "before_text", columnDefinition = "TEXT")
    private String beforeText;

    @Column(name = "after_text", columnDefinition = "TEXT")
    private String afterText;

    @Column(name = "context")
    private String context;

    @Column(name = "mode", length = 50)
    private String mode;

    @Column(name = "count", nullable = false)
    private Integer count = 1;

    @Column(name = "auto_rule", nullable = false)
    private Boolean autoRule = false;

    @Column(name = "created_at", nullable = false, updatable = false)
    private OffsetDateTime createdAt;

    @PrePersist
    protected void onCreate() {
        if (createdAt == null) {
            createdAt = OffsetDateTime.now();
        }
    }

    public UUID getId() {
        return id;
    }

    public void setId(UUID id) {
        this.id = id;
    }

    public User getUser() {
        return user;
    }

    public void setUser(User user) {
        this.user = user;
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
