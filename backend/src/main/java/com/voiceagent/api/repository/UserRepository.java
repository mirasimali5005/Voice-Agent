package com.voiceagent.api.repository;

import com.voiceagent.api.model.User;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;
import java.util.UUID;

@Repository
public interface UserRepository extends JpaRepository<User, UUID> {

    Optional<User> findByAppleId(String appleId);

    Optional<User> findByEmail(String email);
}
