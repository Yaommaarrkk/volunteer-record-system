package com.example.backend.user.service;

import com.example.backend.user.dto.request.UpdatePasswordRequest;
import com.example.backend.user.repository.UserRepository;
import com.example.backend.user.domain.User;
import com.example.backend.auth.config.PasswordConfig;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import lombok.RequiredArgsConstructor;

@Service
@RequiredArgsConstructor
public class UserService {

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    
    public void updatePassword(Long id, UpdatePasswordRequest request) {
        User user = userRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("User not found"));

        // 驗證舊密碼
        if (!passwordEncoder.matches(
                request.oldPassword(),
                user.getPasswordHash()
        )) {
            throw new RuntimeException("Old password is incorrect");
        }

        // 更新密碼
        user.setPasswordHash(passwordEncoder.encode(request.newPassword()));

        userRepository.save(user);
    }
}
