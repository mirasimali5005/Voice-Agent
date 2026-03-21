package com.voiceagent.api.repository;

import com.voiceagent.api.model.Correction;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface CorrectionRepository extends JpaRepository<Correction, UUID> {

    List<Correction> findByUserIdOrderByCreatedAtDesc(UUID userId);

    List<Correction> findByUserIdAndAutoRuleTrue(UUID userId);
}
