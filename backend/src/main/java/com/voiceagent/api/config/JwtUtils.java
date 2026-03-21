package com.voiceagent.api.config;

import org.springframework.security.core.Authentication;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.server.resource.authentication.JwtAuthenticationToken;

import java.util.UUID;

/**
 * Utility class for extracting user information from JWT tokens.
 * Supports both Supabase JWT format and standard JWT format.
 */
public final class JwtUtils {

    private JwtUtils() {
        // Utility class — no instantiation
    }

    /**
     * Extract the user ID (UUID) from the JWT "sub" claim.
     *
     * Supabase tokens store the user UUID in the standard "sub" claim.
     * Standard JWTs also use "sub" for the subject/user identifier.
     *
     * @param authentication the Spring Security Authentication object
     * @return the user's UUID
     * @throws IllegalArgumentException if the authentication is not JWT-based
     *         or the "sub" claim is missing/invalid
     */
    public static UUID extractUserId(Authentication authentication) {
        if (authentication == null) {
            throw new IllegalArgumentException("Authentication must not be null");
        }

        Jwt jwt = extractJwt(authentication);
        String subject = jwt.getSubject();

        if (subject == null || subject.isBlank()) {
            throw new IllegalArgumentException("JWT 'sub' claim is missing or empty");
        }

        try {
            return UUID.fromString(subject);
        } catch (IllegalArgumentException e) {
            throw new IllegalArgumentException(
                    "JWT 'sub' claim is not a valid UUID: " + subject, e);
        }
    }

    /**
     * Extract the raw JWT from the Authentication object.
     */
    private static Jwt extractJwt(Authentication authentication) {
        if (authentication instanceof JwtAuthenticationToken jwtAuth) {
            return jwtAuth.getToken();
        }

        Object principal = authentication.getPrincipal();
        if (principal instanceof Jwt jwt) {
            return jwt;
        }

        throw new IllegalArgumentException(
                "Authentication is not JWT-based: " + authentication.getClass().getSimpleName());
    }
}
