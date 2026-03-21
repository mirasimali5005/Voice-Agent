package com.voiceagent.api.service;

import com.voiceagent.api.dto.DictationDTO;
import com.voiceagent.api.model.Dictation;
import com.voiceagent.api.model.User;
import com.voiceagent.api.repository.DictationRepository;
import com.voiceagent.api.repository.UserRepository;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.UUID;
import java.util.stream.Collectors;

@Service
public class DictationService {

    private final DictationRepository dictationRepository;
    private final UserRepository userRepository;

    public DictationService(DictationRepository dictationRepository, UserRepository userRepository) {
        this.dictationRepository = dictationRepository;
        this.userRepository = userRepository;
    }

    public List<DictationDTO> getDictations(UUID userId, String search, int limit) {
        PageRequest pageRequest = PageRequest.of(0, limit);
        Page<Dictation> page;

        if (search != null && !search.isBlank()) {
            page = dictationRepository.searchByUserIdAndText(userId, search, pageRequest);
        } else {
            page = dictationRepository.findByUserIdOrderByTimestampDesc(userId, pageRequest);
        }

        return page.getContent().stream()
                .map(this::toDTO)
                .collect(Collectors.toList());
    }

    @Transactional
    public DictationDTO storeDictation(DictationDTO dto) {
        User user = userRepository.findById(dto.getUserId())
                .orElseThrow(() -> new IllegalArgumentException("User not found: " + dto.getUserId()));

        Dictation dictation = new Dictation();
        dictation.setUser(user);
        dictation.setTimestamp(dto.getTimestamp());
        dictation.setDurationSeconds(dto.getDurationSeconds());
        dictation.setRawTranscript(dto.getRawTranscript());
        dictation.setCleanedText(dto.getCleanedText());
        dictation.setWasPasted(dto.getWasPasted());
        dictation.setContext(dto.getContext());
        dictation.setMode(dto.getMode());

        Dictation saved = dictationRepository.save(dictation);
        return toDTO(saved);
    }

    private DictationDTO toDTO(Dictation d) {
        DictationDTO dto = new DictationDTO();
        dto.setId(d.getId());
        dto.setUserId(d.getUser().getId());
        dto.setTimestamp(d.getTimestamp());
        dto.setDurationSeconds(d.getDurationSeconds());
        dto.setRawTranscript(d.getRawTranscript());
        dto.setCleanedText(d.getCleanedText());
        dto.setWasPasted(d.getWasPasted());
        dto.setContext(d.getContext());
        dto.setMode(d.getMode());
        dto.setCreatedAt(d.getCreatedAt());
        return dto;
    }
}
