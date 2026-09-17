package com.example.backend.user.service;

import java.time.LocalDateTime;
import java.time.ZoneOffset;
import java.util.Optional;
import io.vavr.control.Either;
import com.example.backend.user.dto.request.UpdatePasswordRequest;
import com.example.backend.user.repository.UserRepository;
import com.example.backend.user.domain.User;
import com.example.backend.user.domain.Role;
import com.example.backend.auth.config.PasswordConfig;
import com.example.backend.common.util.ApiResponse;

import org.springframework.http.ResponseEntity;
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

    public Either<String, User> createUser(String username, String password, Role role){
        Optional<User> maybeUser = userRepository.findByUsername(username);

        if (maybeUser.isPresent()) {
            return Either.left("該使用者已經存在");
        }

        if (password.length() > 20 || password.length() < 4) {
            return Either.left("密碼長度需介於4~20之間");
        }

        long id = userRepository.nextId();
        String passwordHash = passwordEncoder.encode(password);
        User user = new User(id, username, passwordHash, role);

        LocalDateTime createdAt = userRepository.insert(user); // 執行SQL並拿到回傳的createdAt
        user.setCreatedAt(createdAt.toInstant(ZoneOffset.UTC)); // 把User的最後一項createdAt填完整

        return Either.right(user);
    }
}
