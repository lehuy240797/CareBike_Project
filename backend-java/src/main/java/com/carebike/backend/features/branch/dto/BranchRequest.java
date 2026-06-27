package com.carebike.backend.features.branch.dto;

import lombok.Data;
import java.math.BigDecimal;

@Data
public class BranchRequest {
    // Thông tin cơ sở vật chất
    private String name;
    private String address;
    private String phone;
    private String status;
    private BigDecimal latitude;
    private BigDecimal longitude;

    public Integer getManagerId() {
        return managerId;
    }

    private Integer managerId;
}