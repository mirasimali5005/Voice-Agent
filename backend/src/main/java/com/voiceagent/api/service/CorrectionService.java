package com.voiceagent.api.service;

import com.voiceagent.api.dto.CorrectionDTO;
import com.voiceagent.api.model.Correction;
import com.voiceagent.api.model.User;
import com.voiceagent.api.repository.CorrectionRepository;
import com.voiceagent.api.repository.UserRepository;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import java.util.stream.Collectors;

@Service
public class CorrectionService {

    private final CorrectionRepository correctionRepository;
    private final UserRepository userRepository;

    public CorrectionService(CorrectionRepository correctionRepository, UserRepository userRepository) {
        this.correctionRepository = correctionRepository;
        this.userRepository = userRepository;
    }

    @Transactional
    public List<CorrectionDTO> saveCorrections(List<CorrectionDTO> dtos) {
        List<CorrectionDTO> results = new ArrayList<>();

        for (CorrectionDTO dto : dtos) {
            User user = userRepository.findById(dto.getUserId())
                    .orElseThrow(() -> new IllegalArgumentException("User not found: " + dto.getUserId()));

            String context = dto.getContext() != null ? dto.getContext() : "";

            // Check if same before+after+context exists for this user — increment count
            Optional<Correction> existing = correctionRepository
                    .findByUserIdAndBeforeTextAndAfterTextAndContext(
                            dto.getUserId(), dto.getBeforeText(), dto.getAfterText(), context);

            Correction correction;
            if (existing.isPresent()) {
                correction = existing.get();
                correction.setCount(correction.getCount() + 1);
            } else {
                correction = new Correction();
                correction.setUser(user);
                correction.setBeforeText(dto.getBeforeText());
                correction.setAfterText(dto.getAfterText());
                correction.setContext(context);
                correction.setMode(dto.getMode());
                correction.setCount(1);
                correction.setAutoRule(false);
            }

            Correction saved = correctionRepository.save(correction);
            results.add(toDTO(saved));
        }

        return results;
    }

    public List<CorrectionDTO> getCorrections(UUID userId, int limit) {
        return correctionRepository.findByUserIdOrderByCountDesc(userId, PageRequest.of(0, limit))
                .stream()
                .map(this::toDTO)
                .collect(Collectors.toList());
    }

    @Transactional
    public void deleteCorrection(UUID id) {
        if (!correctionRepository.existsById(id)) {
            throw new IllegalArgumentException("Correction not found: " + id);
        }
        correctionRepository.deleteById(id);
    }

    private CorrectionDTO toDTO(Correction c) {
        CorrectionDTO dto = new CorrectionDTO();
        dto.setId(c.getId());
        dto.setUserId(c.getUser().getId());
        dto.setBeforeText(c.getBeforeText());
        dto.setAfterText(c.getAfterText());
        dto.setContext(c.getContext());
        dto.setMode(c.getMode());
        dto.setCount(c.getCount());
        dto.setAutoRule(c.getAutoRule());
        dto.setCreatedAt(c.getCreatedAt());
        return dto;
    }
}
