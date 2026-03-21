package com.voiceagent.api.dto;

public class RuleCompareRequest {

    private String patternRules;
    private String cloudRules;

    public RuleCompareRequest() {}

    public String getPatternRules() {
        return patternRules;
    }

    public void setPatternRules(String patternRules) {
        this.patternRules = patternRules;
    }

    public String getCloudRules() {
        return cloudRules;
    }

    public void setCloudRules(String cloudRules) {
        this.cloudRules = cloudRules;
    }
}
