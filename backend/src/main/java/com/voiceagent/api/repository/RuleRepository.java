package com.voiceagent.api.repository;

import com.voiceagent.api.model.Rule;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface RuleRepository extends JpaRepository<Rule, UUID> {

    List<Rule> findByUserIdOrderByConfidenceDesc(UUID userId);

    List<Rule> findByUserIdAndRuleType(UUID userId, String ruleType);

    List<Rule> findByUserIdAndContext(UUID userId, String context);
}
