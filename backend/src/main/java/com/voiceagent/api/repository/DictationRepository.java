package com.voiceagent.api.repository;

import com.voiceagent.api.model.Dictation;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.UUID;

@Repository
public interface DictationRepository extends JpaRepository<Dictation, UUID> {

    Page<Dictation> findByUserIdOrderByTimestampDesc(UUID userId, Pageable pageable);
}
