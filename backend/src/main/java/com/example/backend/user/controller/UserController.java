package com.example.backend.user.controller;

import java.util.Optional;
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
import com.example.backend.common.dto.response.Response;
import com.example.backend.common.util.ApiResponse;
import lombok.RequiredArgsConstructor;

@RestController
@RequiredArgsConstructor
@RequestMapping("/api")
@CrossOrigin(origins = {
        "http://127.0.0.1:3000",
        "http://localhost:3000",
        "https://user-record-system-frontend.onrender.com"
})
public class UserController {

    private final UserRepository userRepository;
    private final UserService userService;

    @GetMapping("/user/{name}")
    public ResponseEntity<Response<User>> getUser(@PathVariable String name) {
        Optional<User> user = userRepository.findByUsername(name);

        if (user.isPresent()) {
            return ResponseEntity.ok(ApiResponse.success(user.get()));
        }

        return ResponseEntity
                .status(HttpStatus.NOT_FOUND)
                .body(ApiResponse.fail("使用者: <" + name + "> 不存在"));

    }

    // @GetMapping("/users")
    // public ResponseEntity<Response<List<User>>> getUsers() {
    //     List<User> users = userRepository.getAll();
    //     return ResponseEntity.ok(
    //             ApiResponse.success(users)
    //     );
    // }

    @PatchMapping("/user/{id}/password")
    public ResponseEntity<Response<Void>> updatePassword(
        @PathVariable Long id,
        @RequestBody UpdatePasswordRequest request
    ) {
        userService.updatePassword(id, request);

        return ResponseEntity.ok(ApiResponse.success("修改學年(所有學生age)成功", null));
    }

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
