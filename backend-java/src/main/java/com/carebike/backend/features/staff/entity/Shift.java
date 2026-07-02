package com.carebike.backend.features.staff.entity;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import jakarta.persistence.*;
import lombok.*;

@Entity
@Table(name = "shifts")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Shift {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    @ManyToOne(fetch = FetchType.EAGER)
    @JoinColumn(name = "staff_id", nullable = false)
    @JsonIgnoreProperties({"branch"})
    private Staff staff;

    /** Ngày làm việc cụ thể */
    @Column(name = "shift_date", nullable = false)
    private java.time.LocalDate shiftDate;

    /** Ca làm việc: MORNING (6h-14h), AFTERNOON (14h-22h), NIGHT (22h-6h) */
    @Column(name = "shift_type", nullable = false, length = 20)
    private String shiftType;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "branch_id", nullable = false)
    @JsonIgnoreProperties({"manager", "createdAt", "hibernateLazyInitializer"})
    private com.carebike.backend.features.branch.entity.Branch branch;
}
