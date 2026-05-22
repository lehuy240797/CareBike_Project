package com.carebike.backend.features.branch.dto;

import lombok.Data;
import java.math.BigDecimal;

@Data
public class BranchRegistrationRequest {
// 1. Các trường của bảng BRANCHES (Thông tin cơ sở)
    private String branchName;
    private String branchAddress;
    private String branchPhone;
    private BigDecimal latitude;
    private BigDecimal longitude;
    private String branchStatus;

    // 2. Các trường của bảng USERS (Thông tin tài khoản quản lý)
    private String username;
    private String password;
    private String email;
    private String fullName;
    private String userPhone;
}