package com.voiceagent.api.repository;

import com.voiceagent.api.model.Context;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface ContextRepository extends JpaRepository<Context, UUID> {

    List<Context> findByUserId(UUID userId);

    Optional<Context> findByUserIdAndAppName(UUID userId, String appName);
}
