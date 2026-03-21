package com.voiceagent.api.repository;

import com.voiceagent.api.model.Correction;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface CorrectionRepository extends JpaRepository<Correction, UUID> {

    List<Correction> findByUserIdOrderByCreatedAtDesc(UUID userId);

    List<Correction> findByUserIdAndAutoRuleTrue(UUID userId);

    List<Correction> findByUserIdOrderByCountDesc(UUID userId, Pageable pageable);

    @Query("SELECT c FROM Correction c WHERE c.user.id = :userId " +
           "AND c.beforeText = :beforeText AND c.afterText = :afterText AND c.context = :context")
    Optional<Correction> findByUserIdAndBeforeTextAndAfterTextAndContext(
            @Param("userId") UUID userId,
            @Param("beforeText") String beforeText,
            @Param("afterText") String afterText,
            @Param("context") String context);

    @Query("SELECT c FROM Correction c WHERE c.user.id = :userId AND c.count >= :minCount")
    List<Correction> findByUserIdAndCountGreaterThanEqual(
            @Param("userId") UUID userId,
            @Param("minCount") int minCount);

    long countByUserId(UUID userId);
}
