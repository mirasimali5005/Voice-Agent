package com.voiceagent.api.repository;

import com.voiceagent.api.model.Rule;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface RuleRepository extends JpaRepository<Rule, UUID> {

    List<Rule> findByUserIdOrderByConfidenceDesc(UUID userId);

    List<Rule> findByUserIdAndRuleType(UUID userId, String ruleType);

    List<Rule> findByUserIdAndContext(UUID userId, String context);

    @Query("SELECT r FROM Rule r WHERE r.user.id = :userId " +
           "AND r.pattern = :pattern AND r.replacement = :replacement")
    Optional<Rule> findByUserIdAndPatternAndReplacement(
            @Param("userId") UUID userId,
            @Param("pattern") String pattern,
            @Param("replacement") String replacement);

    void deleteByUserId(UUID userId);
}
