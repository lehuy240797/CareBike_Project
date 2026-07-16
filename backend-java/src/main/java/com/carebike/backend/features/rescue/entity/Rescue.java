package com.carebike.backend.features.rescue.entity;

import com.carebike.backend.features.auth.entity.User; // Import đúng đường dẫn của bạn
import com.carebike.backend.features.branch.entity.Branch; // Import đúng đường dẫn
import com.carebike.backend.features.vehicle.entity.Vehicle; // Import đúng đường dẫn
import jakarta.persistence.*;
import lombok.*;
import java.time.LocalDateTime;

@Entity
@Table(name = "rescues")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Rescue {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    // Liên kết với Khách hàng
    @ManyToOne(fetch = FetchType.EAGER)
    @JoinColumn(name = "customer_id", nullable = false)
    private User customer;

    // Liên kết với Xe đang hỏng
    @ManyToOne(fetch = FetchType.EAGER)
    @JoinColumn(name = "vehicle_id", nullable = false)
    private Vehicle vehicle;

    // Liên kết với Chi nhánh tiếp nhận
    @ManyToOne(fetch = FetchType.EAGER)
    @JoinColumn(name = "branch_id", nullable = false)
    private Branch branch;

    // Tọa độ khách hàng
    private Double latitude;
    private Double longitude;

    // Mô tả sự cố
    @Column(columnDefinition = "NVARCHAR(MAX)")
    private String issueDescription;

    // Trạng thái: PENDING (Chờ nhận), ACCEPTED (Đã nhận), COMPLETED (Xong), CANCELLED (Hủy)
    private String status;

    // Mã nhân viên thực hiện sửa chữa (CBS-xxxx)
    @Column(name = "staff_code", length = 20)
    private String staffCode;

    @Transient
    private String assignedStaffName;

    @Transient
    private String assignedStaffPhone;

    // Hệ số giá theo khung giờ (x1 ban ngày, x2 ban đêm)
    @Column(name = "time_multiplier")
    private Double timeMultiplier;

    // Khoảng cách chi nhánh - khách hàng (km, Haversine)
    @Column(name = "distance_km")
    private Double distanceKm;

    // Phí vận chuyển xe (nếu có)
    @Column(name = "transport_fee")
    private java.math.BigDecimal transportFee;

    // Tổng tiền thanh toán của hóa đơn
    @Column(name = "total_cost")
    private java.math.BigDecimal totalCost;

    // Chi tiết hóa đơn (text)
    @Column(name = "invoice_details", columnDefinition = "NVARCHAR(MAX)")
    private String invoiceDetails;

    @Column(name = "created_at", updatable = false)
    private LocalDateTime createdAt;
    @Column(name = "completed_at")
    private LocalDateTime completedAt;


    @PrePersist
    protected void onCreate() {
        createdAt = LocalDateTime.now();
    }
}