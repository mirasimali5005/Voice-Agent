package com.voiceagent.api.repository;

import com.voiceagent.api.model.Dictation;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.UUID;

@Repository
public interface DictationRepository extends JpaRepository<Dictation, UUID> {

    Page<Dictation> findByUserIdOrderByTimestampDesc(UUID userId, Pageable pageable);

    @Query("SELECT d FROM Dictation d WHERE d.user.id = :userId " +
           "AND (LOWER(d.rawTranscript) LIKE LOWER(CONCAT('%', :search, '%')) " +
           "OR LOWER(d.cleanedText) LIKE LOWER(CONCAT('%', :search, '%'))) " +
           "ORDER BY d.timestamp DESC")
    Page<Dictation> searchByUserIdAndText(
            @Param("userId") UUID userId,
            @Param("search") String search,
            Pageable pageable);
}
