package com.carebike.backend.features.staff.entity;

import com.carebike.backend.features.branch.entity.Branch;
import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import jakarta.persistence.*;
import lombok.*;

@Entity
@Table(name = "staffs")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Staff {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    /** Mã nhân viên theo cấu trúc CBS-xxxx (VD: CBS-0001) */
    @Column(name = "staff_code", nullable = false, unique = true, length = 20)
    private String staffCode;

    @Column(name = "full_name", nullable = false, columnDefinition = "NVARCHAR(255)")
    private String fullName;

    @Column(length = 20)
    private String phone;

    @ManyToOne(fetch = FetchType.EAGER)
    @JoinColumn(name = "branch_id", nullable = false)
    @JsonIgnoreProperties({"manager", "createdAt"})
    private Branch branch;

    @Enumerated(EnumType.STRING)
    @Column(name = "status")
    @Builder.Default
    private StaffStatus status = StaffStatus.FREE;
}
