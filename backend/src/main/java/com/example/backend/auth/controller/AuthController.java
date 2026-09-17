package com.example.backend.auth.controller;

import java.util.Optional;
import io.vavr.control.Either;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.bind.annotation.CrossOrigin;

import com.example.backend.user.domain.User;
import com.example.backend.user.dto.request.UpdatePasswordRequest;
import com.example.backend.user.repository.UserRepository;
import com.example.backend.user.service.UserService;

import io.vavr.control.Either;

import com.example.backend.auth.dto.request.RegisterRequest;
import com.example.backend.auth.dto.response.AuthResponse;
import com.example.backend.auth.dto.response.UserDto;
import com.example.backend.common.dto.response.Response;
import com.example.backend.common.util.ApiResponse;
import lombok.RequiredArgsConstructor;

@RestController
@RequiredArgsConstructor
@RequestMapping("/api/auth")
@CrossOrigin(origins = {
        "http://127.0.0.1:3000",
        "http://localhost:3000",
        "https://user-record-system-frontend.onrender.com"
})
public class AuthController {

    private final UserRepository userRepository;
    private final UserService userService;

    @PostMapping("/register")
    public ResponseEntity<AuthResponse> register(@RequestBody RegisterRequest request) {
        
        Either<String, User> result = userService.createUser(request.username(), request.password(), request.role());

        if (result.isRight()) { // 成功
            User user = result.get();
            UserDto userDto = UserDto.fromUser(user);
            return ResponseEntity
                    .status(HttpStatus.CREATED)
                    .body(AuthResponse.from("註冊成功", userDto));
        } else { // 失敗
            String errMsg = result.getLeft();
            return ResponseEntity
                    .badRequest()
                    .body(AuthResponse.fromError(errMsg));
        }
    }

    // @GetMapping("/users")
    // public ResponseEntity<Response<List<User>>> getUsers() {
    //     List<User> users = userRepository.getAll();
    //     return ResponseEntity.ok(
    //             ApiResponse.success(users)
    //     );
    // }

    // @PatchMapping("/{id}/password")
    // public ResponseEntity<Response<Void>> updatePassword(
    //     @PathVariable Long id,
    //     @RequestBody UpdatePasswordRequest request
    // ) {
    //     userService.updatePassword(id, request);

    //     return ResponseEntity.ok(ApiResponse.success("修改學年(所有學生age)成功", null));
    // }

    // @DeleteMapping("/user/{id}")
    // public ResponseEntity<Response<Void>> deleteUser(@PathVariable Integer id) {
    //     int deletedRows;
    //     try {
    //         deletedRows = userRepository.deleteById(id);
    //     } catch (SuperAdminException error) {
    //         return ResponseEntity
    //                 .status(HttpStatus.CONFLICT)
    //                 .body(ApiResponse.fail("超級管理員不能被刪除"));
    //     }

    //     if (deletedRows == 0) {
    //         return ResponseEntity
    //                 .status(HttpStatus.NOT_FOUND)
    //                 .body(ApiResponse.fail("編號: <" + id + "> 不存在"));
    //     }

    //     return ResponseEntity.ok(
    //             ApiResponse.success("刪除使用者成功", null)
    //     );
    // }



    private ResponseEntity<Response<Void>> userNotFound(Integer id) {
        return ResponseEntity
                .status(HttpStatus.NOT_FOUND)
                .body(ApiResponse.fail("編號: <" + id + "> 不存在"));
    }

}
