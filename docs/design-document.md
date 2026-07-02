# TÀI LIỆU THIẾT KẾ HỆ THỐNG CAREBIKE

> **Phiên bản:** 1.0  
> **Ngày:** 2026-06-23  
> **Nhóm phát triển:** CareBike Team

---

## MỤC LỤC

1. [Tổng quan dự án](#1-tổng-quan-dự-án)
2. [Kiến trúc hệ thống (Architecture Design)](#2-kiến-trúc-hệ-thống)
3. [Sơ đồ luồng dữ liệu (DFD)](#3-sơ-đồ-luồng-dữ-liệu-dfd)
4. [Sơ đồ thực thể quan hệ (ERD)](#4-sơ-đồ-thực-thể-quan-hệ-erd)
5. [Thiết kế cơ sở dữ liệu](#5-thiết-kế-cơ-sở-dữ-liệu)
6. [Sequence Diagrams](#6-sequence-diagrams)
7. [Thiết kế API](#7-thiết-kế-api)
8. [Luồng nghiệp vụ & Giao diện](#8-luồng-nghiệp-vụ--giao-diện)

---

## 1. TỔNG QUAN DỰ ÁN

### 1.1 Giới thiệu

**CareBike** là hệ thống quản lý dịch vụ bảo dưỡng xe máy tích hợp, cung cấp giải pháp kết nối giữa khách hàng, nhân viên chi nhánh và quản trị viên thông qua ứng dụng di động và nền tảng web.

### 1.2 Mục tiêu

| Mục tiêu | Mô tả |
|----------|-------|
| Quản lý lịch hẹn | Khách hàng đặt lịch bảo dưỡng trực tuyến, nhân viên xác nhận real-time |
| Dịch vụ cứu hộ | Khách hàng yêu cầu cứu hộ khẩn cấp với vị trí GPS |
| Lịch sử bảo dưỡng | Lưu trữ toàn bộ lịch sử dịch vụ của từng xe |
| Chương trình tích điểm | Khuyến khích khách hàng quay lại qua hệ thống tier/points |
| Quản lý phụ tùng | Theo dõi kho phụ tùng và giá bán |
| AI Chatbot | Tư vấn kỹ thuật tự động qua Gemini AI |

### 1.3 Công nghệ sử dụng

| Lớp | Công nghệ | Phiên bản |
|-----|-----------|-----------|
| Backend | Spring Boot (Java 21) | 4.0.6 |
| Database | Microsoft SQL Server | SQLEXPRESS |
| Authentication | Firebase Admin SDK | 9.2.0 |
| Real-time | WebSocket (STOMP) | — |
| AI | Google Gemini API | 2.5 Flash |
| Mobile | Flutter | ^3.11.4 |
| Web Admin | React + TypeScript | 19 / ~6.0 |
| Build Tool | Vite | 8.0.16 |
| Styling | Tailwind CSS | 4.3 |
| State (Mobile) | Provider | ^6.1.2 |

### 1.4 Actors

| Actor | Mô tả |
|-------|-------|
| **CUSTOMER** | Khách hàng — đặt lịch, yêu cầu cứu hộ, xem lịch sử, chat AI |
| **BRANCH** | Nhân viên chi nhánh — xác nhận lịch, xử lý cứu hộ, tạo hóa đơn |
| **ADMIN** | Quản trị viên — quản lý toàn hệ thống, thống kê, quản lý chi nhánh |

---

## 2. KIẾN TRÚC HỆ THỐNG

### 2.1 Sơ đồ kiến trúc tổng thể

```
┌─────────────────────────────────────────────────────────────────┐
│                        CLIENT TIER                              │
│                                                                 │
│   ┌─────────────────┐          ┌──────────────────────────┐    │
│   │  Flutter Mobile  │          │    React Web Admin App   │    │
│   │  (Android/iOS)   │          │  (TypeScript + Vite)     │    │
│   │                 │          │                          │    │
│   │ • Firebase Auth  │          │ • Firebase Auth          │    │
│   │ • Provider State │          │ • React Context          │    │
│   │ • WebSocket      │          │ • WebSocket (STOMP)      │    │
│   │ • Maps/Location  │          │ • React Leaflet Maps     │    │
│   │ • QR Scanner     │          │ • Tailwind CSS           │    │
│   └────────┬────────┘          └───────────┬──────────────┘    │
└────────────┼───────────────────────────────┼────────────────────┘
             │ HTTPS / WSS                   │ HTTPS / WSS
             ▼                               ▼
┌─────────────────────────────────────────────────────────────────┐
│                       SERVER TIER                               │
│                                                                 │
│   ┌──────────────────────────────────────────────────────────┐  │
│   │              Spring Boot Backend (Port 8080)             │  │
│   │                                                          │  │
│   │  ┌──────────────┐  ┌──────────────┐  ┌───────────────┐  │  │
│   │  │  Controllers  │  │   Services   │  │ Repositories  │  │  │
│   │  │  (REST API)   │→ │  (Business   │→ │  (JPA/Data    │  │  │
│   │  │               │  │   Logic)     │  │   Access)     │  │  │
│   │  └──────────────┘  └──────────────┘  └───────┬───────┘  │  │
│   │                                               │           │  │
│   │  ┌──────────────┐  ┌──────────────┐           │           │  │
│   │  │  WebSocket   │  │  Security    │           │           │  │
│   │  │  (STOMP)     │  │  (Firebase   │           │           │  │
│   │  │  Broker      │  │  JWT Filter) │           │           │  │
│   │  └──────────────┘  └──────────────┘           │           │  │
│   └────────────────────────────────────────────────┼─────────┘  │
│                                                     │            │
└─────────────────────────────────────────────────────┼────────────┘
                                                       │
              ┌────────────────────────────────────────┼──────────┐
              │                DATA TIER               │          │
              │                                        ▼          │
              │   ┌──────────────────────────────────────────┐   │
              │   │     Microsoft SQL Server (care_bike)      │   │
              │   │  users | vehicles | branches | appts ...  │   │
              │   └──────────────────────────────────────────┘   │
              └──────────────────────────────────────────────────┘

         ┌────────────────────────────────────────────────────┐
         │               EXTERNAL SERVICES                    │
         │  ┌──────────────┐    ┌──────────────────────────┐  │
         │  │   Firebase   │    │   Google Gemini AI API   │  │
         │  │ (Auth + FCM) │    │  (Chat & Function Call)  │  │
         │  └──────────────┘    └──────────────────────────┘  │
         └────────────────────────────────────────────────────┘
```

### 2.2 Cấu trúc module Backend

```
backend-java/src/main/java/com/carebike/backend/
├── config/
│   ├── SecurityConfig.java       ← Spring Security + CORS
│   ├── WebSocketConfig.java      ← STOMP Broker config
│   └── WebConfig.java            ← MVC config
├── security/
│   └── JwtAuthenticationFilter.java  ← Firebase token validation
├── features/
│   ├── auth/                     ← Đăng ký / đăng nhập
│   ├── vehicle/                  ← Quản lý xe
│   ├── branch/                   ← Quản lý chi nhánh
│   ├── appointment/              ← Đặt lịch hẹn
│   ├── maintenance/              ← Lịch sử bảo dưỡng
│   ├── rescue/                   ← Cứu hộ khẩn cấp
│   ├── sparepart/                ← Phụ tùng
│   ├── category/                 ← Danh mục
│   ├── customer/                 ← Hồ sơ & tích điểm
│   └── chat/                     ← AI Chatbot (Gemini)
└── BackendApplication.java
```

### 2.3 Cấu trúc Mobile App (Flutter)

```
mobile_app/lib/
├── core/              ← Constants, utilities
├── models/            ← Data models (DTO)
├── providers/         ← State management
├── screens/
│   ├── auth/          ← Login / Register
│   ├── tabs/          ← Home, Profile, Vehicles, History
│   ├── branch/        ← Dashboard, Rescue, Bill, Map
│   └── chat/          ← AI Chat interface
├── services/          ← HTTP API clients
└── widgets/           ← Reusable UI components
```

### 2.4 Cấu trúc Web App (React)

```
web-app/src/
├── components/        ← Shared UI, Auth, Modals
├── context/           ← AuthContext (global state)
├── pages/             ← AdminDashboard, BranchManagement, ...
├── routes/            ← ProtectedRoute, RoleRoute
├── services/          ← API clients (axios)
├── types/             ← TypeScript interfaces
└── App.tsx            ← Router config
```

---

## 3. SƠ ĐỒ LUỒNG DỮ LIỆU (DFD)

### 3.1 DFD Level 0 — Tổng quan hệ thống

```
                    ┌─────────────────────────────────────────┐
                    │                                         │
  [CUSTOMER] ──────►│                                         │──────► [CUSTOMER]
  đặt lịch          │                                         │  lịch xác nhận
  yêu cầu cứu hộ    │          HỆ THỐNG CAREBIKE              │  thông báo
  chat AI           │                                         │  lịch sử dịch vụ
                    │                                         │
  [BRANCH]  ──────►│                                         │──────► [BRANCH]
  xác nhận lịch     │                                         │  danh sách lịch hẹn
  hoàn thành dịch vụ│                                         │  yêu cầu cứu hộ
  tạo hóa đơn       │                                         │  thống kê chi nhánh
                    │                                         │
  [ADMIN]   ──────►│                                         │──────► [ADMIN]
  quản lý chi nhánh │                                         │  báo cáo tổng hợp
  quản lý phụ tùng  │                                         │  dashboard real-time
  quản lý nhân viên │                                         │
                    └─────────────────────────────────────────┘
                                       │
                                       ▼
                    ┌─────────────────────────────────────────┐
                    │           SQL Server Database            │
                    │  (users, vehicles, appointments, ...)   │
                    └─────────────────────────────────────────┘
```

### 3.2 DFD Level 1 — Phân rã các tiến trình chính

```
                 ┌──────────────────────────────────────────────────────────┐
                 │                                                          │
[CUSTOMER] ─────►│  1.0 XÁC THỰC ─────────────── D1: users               │
                 │  (Firebase Auth)               D2: roles               │
                 │                                                          │
[CUSTOMER] ─────►│  2.0 QUẢN LÝ XE ─────────────── D3: vehicles           │
                 │  (CRUD xe, QR lookup)                                   │
                 │                                                          │
[CUSTOMER] ─────►│  3.0 ĐẶT LỊCH HẸN ──────────── D4: appointments       │
[BRANCH]  ─────►│  (tạo, xác nhận, hủy)           WebSocket ──► [BRANCH] │
                 │                                                          │
[CUSTOMER] ─────►│  4.0 CỨU HỘ ────────────────── D5: rescues            │
[BRANCH]  ─────►│  (yêu cầu, chấp nhận, hoàn      WebSocket ──► [BRANCH] │
                 │   thành)                                                │
                 │                                                          │
[BRANCH]  ─────►│  5.0 LỊCH SỬ BẢO DƯỠNG ──────── D6: maintenance_history│
                 │  (tạo hóa đơn, ghi lịch sử)    D7: customer_profiles  │
                 │                                                          │
[ADMIN]   ─────►│  6.0 QUẢN LÝ PHỤ TÙNG ─────────  D8: spare_parts       │
                 │  (CRUD phụ tùng, danh mục)      D9: categories         │
                 │                                                          │
[CUSTOMER] ─────►│  7.0 AI CHATBOT ────────────────  Gemini API (External)│
                 │  (hỏi đáp kỹ thuật)                                    │
                 │                                                          │
[ADMIN]   ─────►│  8.0 THỐNG KÊ & BÁO CÁO ───────  WebSocket ──► [ADMIN] │
                 │  (dashboard real-time)                                  │
                 │                                                          │
                 └──────────────────────────────────────────────────────────┘
```

### 3.3 DFD Level 2 — Tiến trình Đặt lịch hẹn (Chi tiết)

```
[CUSTOMER]
    │
    │ (appointmentDate, branchId, note)
    ▼
┌──────────────────────┐
│  3.1 Validate Input  │──── lỗi ────► [CUSTOMER] (thông báo lỗi)
│  (kiểm tra ngày,     │
│   chi nhánh tồn tại) │
└──────────┬───────────┘
           │ dữ liệu hợp lệ
           ▼
┌──────────────────────┐       D4: appointments
│  3.2 Tạo Appointment │──────► (INSERT, status=PENDING)
│  (status: PENDING)   │
└──────────┬───────────┘
           │
           ▼
┌──────────────────────┐
│  3.3 Broadcast via   │──────► WebSocket /topic/branches/{id}
│  WebSocket           │           │
└──────────────────────┘           ▼
                               [BRANCH STAFF]
                                   │
                                   │ xác nhận / hủy
                                   ▼
                        ┌──────────────────────┐   D4: appointments
                        │  3.4 Update Status   │──► (UPDATE status)
                        │  CONFIRMED / CANCELLED│
                        └──────────┬───────────┘
                                   │
                                   ▼
                               [CUSTOMER]
                            (push notification)
```

---

## 4. SƠ ĐỒ THỰC THỂ QUAN HỆ (ERD)

### 4.1 ERD toàn hệ thống (Mermaid)

```mermaid
erDiagram
    ROLES {
        bigint id PK
        varchar roleName
    }

    USERS {
        bigint id PK
        varchar firebaseUid UK
        varchar email UK
        varchar fullName
        varchar phone
        date dob
        varchar gender
        bigint role_id FK
        boolean isActive
    }

    VEHICLES {
        bigint id PK
        varchar brand
        varchar vehicleType
        varchar licensePlate UK
        int engineCapacity
        int currentKm
        bigint owner_id FK
    }

    BRANCHES {
        bigint id PK
        varchar name
        varchar address
        varchar phone
        double latitude
        double longitude
        bigint manager_id FK
        varchar status
    }

    APPOINTMENTS {
        bigint id PK
        bigint customer_id FK
        bigint branch_id FK
        datetime appointmentDate
        varchar note
        varchar status
        datetime createdAt
    }

    MAINTENANCE_HISTORY {
        bigint id PK
        bigint customer_id FK
        bigint branch_id FK
        date serviceDate
        int currentKm
        text serviceDetails
        decimal totalCost
        datetime createdAt
    }

    RESCUES {
        bigint id PK
        bigint customer_id FK
        bigint vehicle_id FK
        bigint branch_id FK
        double latitude
        double longitude
        text issueDescription
        varchar status
        datetime createdAt
    }

    CUSTOMER_PROFILES {
        bigint id PK
        bigint user_id FK UK
        int accumulatedPoints
        varchar memberTier
        decimal totalSpent
    }

    CATEGORIES {
        bigint id PK
        varchar name
        varchar description
    }

    SPARE_PARTS {
        bigint id PK
        varchar name
        decimal price
        text description
        varchar imageUrl
        bigint category_id FK
    }

    ROLES ||--o{ USERS : "has"
    USERS ||--o{ VEHICLES : "owns"
    USERS ||--|| BRANCHES : "manages"
    USERS ||--o{ APPOINTMENTS : "books"
    USERS ||--o{ MAINTENANCE_HISTORY : "has"
    USERS ||--o{ RESCUES : "requests"
    USERS ||--|| CUSTOMER_PROFILES : "has"
    BRANCHES ||--o{ APPOINTMENTS : "receives"
    BRANCHES ||--o{ MAINTENANCE_HISTORY : "performs"
    BRANCHES ||--o{ RESCUES : "handles"
    VEHICLES ||--o{ RESCUES : "involved in"
    CATEGORIES ||--o{ SPARE_PARTS : "contains"
```

### 4.2 Mô tả các mối quan hệ

| Quan hệ | Loại | Mô tả |
|---------|------|-------|
| ROLES → USERS | 1:N | Một vai trò có nhiều người dùng |
| USERS → VEHICLES | 1:N | Một khách hàng có nhiều xe |
| USERS → BRANCHES | 1:1 | Một nhân viên quản lý một chi nhánh |
| USERS → APPOINTMENTS | 1:N | Khách hàng đặt nhiều lịch hẹn |
| USERS → CUSTOMER_PROFILES | 1:1 | Mỗi khách hàng có 1 hồ sơ tích điểm |
| BRANCHES → APPOINTMENTS | 1:N | Chi nhánh nhận nhiều lịch hẹn |
| BRANCHES → RESCUES | 1:N | Chi nhánh xử lý nhiều yêu cầu cứu hộ |
| VEHICLES → RESCUES | 1:N | Xe có thể được cứu hộ nhiều lần |
| CATEGORIES → SPARE_PARTS | 1:N | Danh mục chứa nhiều phụ tùng |

---

## 5. THIẾT KẾ CƠ SỞ DỮ LIỆU

**Database:** Microsoft SQL Server — `care_bike`  
**Kết nối:** `jdbc:sqlserver://LAPTOP-O4IB8J3G\SQLEXPRESS01;databaseName=care_bike`

### 5.1 Bảng ROLES

| Cột | Kiểu | Ràng buộc | Mô tả |
|-----|------|-----------|-------|
| id | BIGINT | PK, AUTO | Khóa chính |
| roleName | VARCHAR(50) | NOT NULL, UNIQUE | ADMIN / BRANCH / CUSTOMER |

### 5.2 Bảng USERS

| Cột | Kiểu | Ràng buộc | Mô tả |
|-----|------|-----------|-------|
| id | BIGINT | PK, AUTO | Khóa chính |
| firebaseUid | VARCHAR(128) | NOT NULL, UNIQUE | Firebase UID |
| email | VARCHAR(255) | NOT NULL, UNIQUE | Email đăng nhập |
| fullName | VARCHAR(255) | NOT NULL | Họ tên đầy đủ |
| phone | VARCHAR(20) | — | Số điện thoại |
| dob | DATE | — | Ngày sinh |
| gender | VARCHAR(10) | — | Giới tính |
| role_id | BIGINT | FK → ROLES | Vai trò |
| isActive | BIT | DEFAULT 1 | Trạng thái tài khoản |

### 5.3 Bảng VEHICLES

| Cột | Kiểu | Ràng buộc | Mô tả |
|-----|------|-----------|-------|
| id | BIGINT | PK, AUTO | Khóa chính |
| brand | VARCHAR(100) | NOT NULL | Hãng xe |
| vehicleType | VARCHAR(100) | NOT NULL | Loại xe |
| licensePlate | VARCHAR(20) | NOT NULL, UNIQUE | Biển số xe |
| engineCapacity | INT | — | Dung tích động cơ (cc) |
| currentKm | INT | DEFAULT 0 | Số km hiện tại |
| owner_id | BIGINT | FK → USERS | Chủ xe |

### 5.4 Bảng BRANCHES

| Cột | Kiểu | Ràng buộc | Mô tả |
|-----|------|-----------|-------|
| id | BIGINT | PK, AUTO | Khóa chính |
| name | VARCHAR(255) | NOT NULL | Tên chi nhánh |
| address | VARCHAR(500) | NOT NULL | Địa chỉ |
| phone | VARCHAR(20) | — | SĐT chi nhánh |
| latitude | DOUBLE | — | Vĩ độ GPS |
| longitude | DOUBLE | — | Kinh độ GPS |
| manager_id | BIGINT | FK → USERS | Quản lý chi nhánh |
| status | VARCHAR(20) | DEFAULT 'ACTIVE' | Trạng thái |

### 5.5 Bảng APPOINTMENTS

| Cột | Kiểu | Ràng buộc | Mô tả |
|-----|------|-----------|-------|
| id | BIGINT | PK, AUTO | Khóa chính |
| customer_id | BIGINT | FK → USERS | Khách hàng |
| branch_id | BIGINT | FK → BRANCHES | Chi nhánh |
| appointmentDate | DATETIME | NOT NULL | Ngày giờ hẹn |
| note | TEXT | — | Ghi chú |
| status | VARCHAR(20) | NOT NULL | PENDING/CONFIRMED/COMPLETED/CANCELLED |
| createdAt | DATETIME | DEFAULT NOW | Thời điểm tạo |

### 5.6 Bảng MAINTENANCE_HISTORY

| Cột | Kiểu | Ràng buộc | Mô tả |
|-----|------|-----------|-------|
| id | BIGINT | PK, AUTO | Khóa chính |
| customer_id | BIGINT | FK → USERS | Khách hàng |
| branch_id | BIGINT | FK → BRANCHES | Chi nhánh thực hiện |
| serviceDate | DATE | NOT NULL | Ngày bảo dưỡng |
| currentKm | INT | — | Số km lúc bảo dưỡng |
| serviceDetails | TEXT | — | Chi tiết dịch vụ |
| totalCost | DECIMAL(15,2) | — | Tổng chi phí (VND) |
| createdAt | DATETIME | DEFAULT NOW | Thời điểm tạo |

### 5.7 Bảng RESCUES

| Cột | Kiểu | Ràng buộc | Mô tả |
|-----|------|-----------|-------|
| id | BIGINT | PK, AUTO | Khóa chính |
| customer_id | BIGINT | FK → USERS | Khách hàng cần cứu hộ |
| vehicle_id | BIGINT | FK → VEHICLES | Xe cần cứu hộ |
| branch_id | BIGINT | FK → BRANCHES | Chi nhánh xử lý |
| latitude | DOUBLE | NOT NULL | Vĩ độ vị trí |
| longitude | DOUBLE | NOT NULL | Kinh độ vị trí |
| issueDescription | TEXT | — | Mô tả sự cố |
| status | VARCHAR(20) | DEFAULT 'PENDING' | PENDING/ACCEPTED/COMPLETED/CANCELLED |
| createdAt | DATETIME | DEFAULT NOW | Thời điểm tạo |

### 5.8 Bảng CUSTOMER_PROFILES

| Cột | Kiểu | Ràng buộc | Mô tả |
|-----|------|-----------|-------|
| id | BIGINT | PK, AUTO | Khóa chính |
| user_id | BIGINT | FK → USERS, UNIQUE | Khách hàng |
| accumulatedPoints | INT | DEFAULT 0 | Điểm tích lũy |
| memberTier | VARCHAR(20) | DEFAULT 'STANDARD' | STANDARD/SILVER/GOLD/PLATINUM |
| totalSpent | DECIMAL(15,2) | DEFAULT 0 | Tổng chi tiêu (VND) |

**Quy tắc phân hạng thành viên:**

| Hạng | Điều kiện (totalSpent) | Điểm tích lũy |
|------|------------------------|---------------|
| STANDARD | < 5.000.000 VND | 1 điểm / 100.000 VND |
| SILVER | ≥ 5.000.000 VND | 1 điểm / 100.000 VND |
| GOLD | ≥ 15.000.000 VND | 1 điểm / 100.000 VND |
| PLATINUM | ≥ 30.000.000 VND | 1 điểm / 100.000 VND |

### 5.9 Bảng SPARE_PARTS & CATEGORIES

**CATEGORIES:**

| Cột | Kiểu | Ràng buộc |
|-----|------|-----------|
| id | BIGINT | PK, AUTO |
| name | VARCHAR(100) | NOT NULL |
| description | TEXT | — |

**SPARE_PARTS:**

| Cột | Kiểu | Ràng buộc | Mô tả |
|-----|------|-----------|-------|
| id | BIGINT | PK, AUTO | Khóa chính |
| name | VARCHAR(255) | NOT NULL | Tên phụ tùng |
| price | DECIMAL(15,2) | NOT NULL | Giá bán |
| description | TEXT | — | Mô tả |
| imageUrl | VARCHAR(500) | — | URL ảnh |
| category_id | BIGINT | FK → CATEGORIES | Danh mục |

---

## 6. SEQUENCE DIAGRAMS

### 6.1 Luồng xác thực (Authentication Flow)

```
Customer/Staff    Firebase        Backend             Database
     │               │               │                   │
     │──── login ────►│               │                   │
     │                │               │                   │
     │◄── idToken ───│               │                   │
     │                │               │                   │
     │────────────── POST /api/auth/register ────────────►│
     │                │   {idToken, ...}                  │
     │                │               │                   │
     │                │               │──verify token────►│ Firebase Admin
     │                │               │◄─ decoded UID ───│
     │                │               │                   │
     │                │               │──── findOrCreate ─►│ SQL Server
     │                │               │◄─── user object ──│
     │                │               │                   │
     │◄──────────────── 200 OK {user, role} ─────────────│
     │                │               │                   │
```

### 6.2 Luồng đặt lịch hẹn (Appointment Booking)

```
Customer        Mobile App       Backend           Database        Branch Staff
    │               │               │                 │                │
    │── chọn CN ──►│               │                 │                │
    │── chọn ngày ─►│               │                 │                │
    │── xác nhận ──►│               │                 │                │
    │               │── POST /api/appointments ──────►│                │
    │               │   {branchId, appointmentDate}   │                │
    │               │               │── INSERT ───────►│                │
    │               │               │   status=PENDING│                │
    │               │               │◄── saved ───────│                │
    │               │               │                 │                │
    │               │               │── WebSocket ─────────────────────►│
    │               │               │   /topic/branches/{id}/appointments│
    │               │◄── 201 ──────│                 │                │
    │◄── thông báo ─│               │                 │                │
    │   "Đặt lịch   │               │                 │── xem lịch ──►│
    │    thành công"│               │                 │                │
    │               │               │                 │                │
    │               │               │◄── PATCH /appointments/{id}/confirm ◄──│
    │               │               │── UPDATE ───────►│                │
    │               │               │   status=CONFIRMED              │
    │◄── notification ──────────────│ (FCM Push)      │                │
    │   "Lịch đã    │               │                 │                │
    │    được xác   │               │                 │                │
    │    nhận"      │               │                 │                │
```

### 6.3 Luồng cứu hộ khẩn cấp (Rescue Request)

```
Customer        Mobile App       Backend           Database        Branch Staff
    │               │               │                 │                │
    │── báo sự cố ─►│               │                 │                │
    │   (vị trí,    │               │                 │                │
    │    mô tả xe)  │               │                 │                │
    │               │── POST /api/rescue ────────────►│                │
    │               │   {lat, lng, vehicleId,         │                │
    │               │    issueDescription}            │                │
    │               │               │── INSERT ───────►│                │
    │               │               │   status=PENDING│                │
    │               │               │◄── saved ───────│                │
    │               │               │                 │                │
    │               │               │── WebSocket ─────────────────────►│
    │               │               │   /topic/branches/{id}/rescue     │
    │               │◄── 201 ──────│                 │                │
    │◄── "Đã gửi   │               │                 │                │
    │    yêu cầu"   │               │                 │── xem map ───►│
    │               │               │                 │   vị trí KH   │
    │               │               │◄── PATCH /rescue/{id}/accept ◄────│
    │               │               │── UPDATE ───────►│                │
    │               │               │   status=ACCEPTED               │
    │◄── FCM Push ──│               │                 │                │
    │   "Nhân viên  │               │                 │                │
    │    đang đến"  │               │                 │                │
    │               │               │◄── PATCH /rescue/{id}/complete ◄─│
    │               │               │── UPDATE ───────►│                │
    │               │               │   status=COMPLETED              │
```

### 6.4 Luồng tích điểm (Loyalty Points)

```
Branch Staff    Mobile App       Backend           Database
    │               │               │                 │
    │── tạo hóa đơn►│               │                 │
    │   (serviceDetails,            │                 │
    │    totalCost, customerId)     │                 │
    │               │── POST /api/maintenance ───────►│
    │               │               │── INSERT maintenance_history ──►│
    │               │               │                 │
    │               │               │── GET customer_profile ─────────►│
    │               │               │◄── profile ─────│                │
    │               │               │                 │
    │               │               │  Tính toán:
    │               │               │  newPoints = totalCost / 100,000
    │               │               │  totalSpent += totalCost
    │               │               │  recalculate memberTier
    │               │               │                 │
    │               │               │── UPDATE customer_profiles ─────►│
    │               │◄── 201 ──────│                 │
    │◄── "Tạo hóa  │               │                 │
    │    đơn thành  │               │                 │
    │    công"      │               │                 │
```

### 6.5 Luồng AI Chat

```
Customer        Mobile App       Backend           Gemini API        Database
    │               │               │                   │               │
    │── nhập câu ──►│               │                   │               │
    │   hỏi         │               │                   │               │
    │               │── POST /api/chat ─────────────────►               │
    │               │   {message, userId}               │               │
    │               │               │── request with ──►│               │
    │               │               │   function_declarations           │
    │               │               │                   │               │
    │               │               │◄── function_call ─│               │
    │               │               │   getSparePartPrice("lốc máy")    │
    │               │               │── query ──────────────────────────►
    │               │               │◄── data ──────────────────────────│
    │               │               │── function_result ►│               │
    │               │               │◄── final response ─│               │
    │               │◄── 200 ──────│                   │               │
    │◄── câu trả lời│               │                   │               │
    │   của AI      │               │                   │               │
```

---

## 7. THIẾT KẾ API

**Base URL:** `http://localhost:8080/api`  
**Authentication:** Firebase ID Token trong header `Authorization: Bearer <token>`  
**Format:** JSON

### 7.1 Authentication

| Method | Endpoint | Body | Response | Mô tả |
|--------|----------|------|----------|-------|
| POST | `/auth/register` | `{firebaseToken, fullName, phone, dob, gender}` | `{id, email, role}` | Đăng ký khách hàng |
| POST | `/auth/login` | `{firebaseToken}` | `{user, role}` | Đăng nhập |

### 7.2 Vehicles

| Method | Endpoint | Auth | Mô tả |
|--------|----------|------|-------|
| GET | `/vehicles/owner/{userId}` | CUSTOMER/ADMIN | Lấy danh sách xe của user |
| PUT | `/vehicles/owner/{userId}` | CUSTOMER | Thêm/cập nhật xe |
| GET | `/vehicles/lookup?licensePlate=X` | ALL | Tra cứu xe theo biển số (QR) |
| DELETE | `/vehicles/{id}` | CUSTOMER | Xóa xe |

### 7.3 Branches

| Method | Endpoint | Auth | Mô tả |
|--------|----------|------|-------|
| GET | `/branch` | ALL | Danh sách tất cả chi nhánh |
| POST | `/branch` | ADMIN | Tạo chi nhánh mới |
| GET | `/branch/{id}` | ALL | Chi tiết chi nhánh |
| PUT | `/branch/{id}` | ADMIN | Cập nhật chi nhánh |
| DELETE | `/branch/{id}` | ADMIN | Xóa chi nhánh |
| GET | `/branch/nearby?lat=X&lon=Y` | ALL | Tìm chi nhánh gần nhất |

### 7.4 Appointments

| Method | Endpoint | Auth | Mô tả |
|--------|----------|------|-------|
| POST | `/appointments` | CUSTOMER | Đặt lịch hẹn mới |
| GET | `/appointments/customer/{id}` | CUSTOMER | Lịch hẹn của khách |
| GET | `/appointments/branch/{id}` | BRANCH | Lịch hẹn của chi nhánh |
| PATCH | `/appointments/{id}/confirm` | BRANCH | Xác nhận lịch hẹn |
| PATCH | `/appointments/{id}/cancel` | BRANCH/CUSTOMER | Hủy lịch hẹn |
| PATCH | `/appointments/{id}/complete` | BRANCH | Hoàn thành lịch hẹn |

**Request body (POST /appointments):**
```json
{
  "customerId": 1,
  "branchId": 2,
  "appointmentDate": "2026-07-01T09:00:00",
  "note": "Thay nhớt, kiểm tra phanh"
}
```

### 7.5 Maintenance History

| Method | Endpoint | Auth | Mô tả |
|--------|----------|------|-------|
| POST | `/maintenance` | BRANCH | Tạo hóa đơn bảo dưỡng |
| GET | `/maintenance/customer/{id}` | CUSTOMER/ADMIN | Lịch sử của khách |
| GET | `/maintenance/branch/{id}` | BRANCH/ADMIN | Lịch sử của chi nhánh |

**Request body (POST /maintenance):**
```json
{
  "customerId": 1,
  "branchId": 2,
  "serviceDate": "2026-06-23",
  "currentKm": 12500,
  "serviceDetails": "Thay nhớt, vệ sinh bugi",
  "totalCost": 350000
}
```

### 7.6 Rescue

| Method | Endpoint | Auth | Mô tả |
|--------|----------|------|-------|
| POST | `/rescue` | CUSTOMER | Yêu cầu cứu hộ |
| GET | `/rescue/customer/{id}` | CUSTOMER | Lịch sử cứu hộ của khách |
| GET | `/rescue/branch/{id}` | BRANCH | Yêu cầu cứu hộ của chi nhánh |
| PATCH | `/rescue/{id}/accept` | BRANCH | Chấp nhận cứu hộ |
| PATCH | `/rescue/{id}/complete` | BRANCH | Hoàn thành cứu hộ |
| PATCH | `/rescue/{id}/cancel` | BRANCH/CUSTOMER | Hủy cứu hộ |

**Request body (POST /rescue):**
```json
{
  "customerId": 1,
  "vehicleId": 3,
  "branchId": 2,
  "latitude": 10.7769,
  "longitude": 106.7009,
  "issueDescription": "Xe bị hết xăng giữa đường"
}
```

### 7.7 Spare Parts & Categories

| Method | Endpoint | Auth | Mô tả |
|--------|----------|------|-------|
| GET | `/spare-parts` | ALL | Danh sách phụ tùng |
| POST | `/spare-parts` | ADMIN | Thêm phụ tùng |
| PUT | `/spare-parts/{id}` | ADMIN | Cập nhật phụ tùng |
| DELETE | `/spare-parts/{id}` | ADMIN | Xóa phụ tùng |
| GET | `/spare-parts/category/{id}` | ALL | Phụ tùng theo danh mục |
| GET | `/categories` | ALL | Danh sách danh mục |
| POST | `/categories` | ADMIN | Tạo danh mục |
| PUT | `/categories/{id}` | ADMIN | Cập nhật danh mục |

### 7.8 Chat AI

| Method | Endpoint | Body | Mô tả |
|--------|----------|------|-------|
| POST | `/chat` | `{message, userId}` | Gửi câu hỏi đến Gemini AI |

### 7.9 WebSocket Endpoints

| Topic | Mô tả | Subscriber |
|-------|-------|------------|
| `/topic/admin/stats` | Thống kê real-time | ADMIN |
| `/topic/branches/{id}/appointments` | Lịch hẹn mới/cập nhật | BRANCH |
| `/topic/branches/{id}/rescue` | Yêu cầu cứu hộ mới | BRANCH |

---

## 8. LUỒNG NGHIỆP VỤ & GIAO DIỆN

### 8.1 Luồng nghiệp vụ tổng thể

```
┌─────────────────────────────────────────────────────────────────┐
│                    CUSTOMER JOURNEY                             │
│                                                                 │
│  Đăng ký/Đăng nhập                                             │
│       │                                                         │
│       ▼                                                         │
│  ┌──────────┐   ┌──────────┐   ┌──────────┐   ┌──────────┐   │
│  │ Thêm xe  │   │ Tìm CN   │   │ Đặt lịch │   │ Xem lịch │   │
│  │(biển số, │──►│ gần nhất │──►│  hẹn     │──►│  sử bảo  │   │
│  │ loại xe) │   │ (bản đồ) │   │          │   │ dưỡng    │   │
│  └──────────┘   └──────────┘   └──────────┘   └──────────┘   │
│                                                                 │
│  ┌──────────┐   ┌──────────┐   ┌──────────┐                   │
│  │ Cứu hộ  │   │ Chat AI  │   │ Xem      │                   │
│  │ khẩn cấp│   │ (tư vấn) │   │ điểm &   │                   │
│  │ (GPS)   │   │          │   │ hạng thẻ │                   │
│  └──────────┘   └──────────┘   └──────────┘                   │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                   BRANCH STAFF JOURNEY                          │
│                                                                 │
│  ┌──────────┐   ┌──────────┐   ┌──────────┐   ┌──────────┐   │
│  │ Dashboard│   │ Xác nhận │   │ Tạo hóa  │   │ Xử lý   │   │
│  │ chi nhánh│──►│ lịch hẹn │──►│ đơn bảo  │──►│ cứu hộ  │   │
│  │ (real-   │   │ (real-   │   │ dưỡng    │   │ (bản đồ)│   │
│  │  time)   │   │  time)   │   │          │   │          │   │
│  └──────────┘   └──────────┘   └──────────┘   └──────────┘   │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                     ADMIN JOURNEY                               │
│                                                                 │
│  ┌──────────┐   ┌──────────┐   ┌──────────┐   ┌──────────┐   │
│  │ Dashboard│   │ Quản lý  │   │ Quản lý  │   │ Quản lý  │   │
│  │ tổng hợp │   │ chi nhánh│   │ phụ tùng │   │ khách    │   │
│  │ (stats)  │   │ (CRUD)   │   │ (CRUD)   │   │ hàng     │   │
│  └──────────┘   └──────────┘   └──────────┘   └──────────┘   │
│                                                                 │
│  ┌──────────┐   ┌──────────┐                                   │
│  │ Quản lý  │   │ Giám sát │                                   │
│  │ nhân viên│   │ cứu hộ   │                                   │
│  │          │   │ real-time│                                   │
│  └──────────┘   └──────────┘                                   │
└─────────────────────────────────────────────────────────────────┘
```

### 8.2 Mô tả các màn hình Mobile App

| Màn hình | Role | Chức năng chính |
|----------|------|-----------------|
| Login / Register | ALL | Đăng nhập Firebase, đăng ký tài khoản |
| Home Tab | CUSTOMER | Tổng quan, thông báo, lịch hẹn gần nhất |
| Vehicles Tab | CUSTOMER | Danh sách xe, thêm xe, quét QR |
| History Tab | CUSTOMER | Lịch sử bảo dưỡng và cứu hộ |
| Profile Tab | CUSTOMER | Thông tin cá nhân, hạng thành viên, điểm |
| Branch Map | CUSTOMER | Bản đồ chi nhánh gần nhất |
| Appointment Screen | CUSTOMER | Đặt lịch hẹn mới |
| Rescue Bottom Sheet | CUSTOMER | Yêu cầu cứu hộ khẩn cấp |
| Chat Screen | CUSTOMER | Tư vấn AI với Gemini |
| Branch Dashboard | BRANCH | Thống kê chi nhánh, lịch hẹn hôm nay |
| Branch Rescue Screen | BRANCH | Danh sách cứu hộ, xem bản đồ |
| Create Bill Screen | BRANCH | Tạo hóa đơn bảo dưỡng |

### 8.3 Mô tả các trang Web Admin

| Trang | Role | Chức năng |
|-------|------|-----------|
| Login | ALL | Đăng nhập Firebase |
| Admin Dashboard | ADMIN | Thống kê real-time (WebSocket): số lịch hẹn, cứu hộ, doanh thu |
| Branch Dashboard | BRANCH | Dashboard riêng của chi nhánh |
| Branch Management | ADMIN | CRUD chi nhánh, thiết lập tọa độ GPS |
| Customer Management | ADMIN | Danh sách khách hàng, hạng thành viên |
| Staff Management | ADMIN | Quản lý tài khoản nhân viên |
| Category Management | ADMIN | CRUD danh mục phụ tùng |
| Spare Part Management | ADMIN | CRUD phụ tùng, quản lý giá |
| Rescue Dashboard | ADMIN/BRANCH | Giám sát yêu cầu cứu hộ real-time |
| Change Password | ALL | Đổi mật khẩu Firebase |

### 8.4 Phân quyền truy cập

| Tài nguyên | ADMIN | BRANCH | CUSTOMER |
|------------|-------|--------|----------|
| Quản lý chi nhánh | ✅ CRUD | ❌ | ❌ |
| Quản lý nhân viên | ✅ CRUD | ❌ | ❌ |
| Quản lý phụ tùng | ✅ CRUD | ✅ Xem | ✅ Xem |
| Lịch hẹn | ✅ Tất cả | ✅ Chi nhánh | ✅ Cá nhân |
| Cứu hộ | ✅ Tất cả | ✅ Xử lý | ✅ Yêu cầu |
| Bảo dưỡng | ✅ Tất cả | ✅ Tạo | ✅ Xem |
| Thống kê | ✅ Tổng hợp | ✅ Chi nhánh | ❌ |
| AI Chat | ❌ | ❌ | ✅ |
| Tích điểm | ✅ Xem | ❌ | ✅ Cá nhân |

---

## PHỤ LỤC

### A. Môi trường phát triển

| Thành phần | Yêu cầu |
|------------|---------|
| JDK | 21+ |
| Maven | 3.9+ |
| Node.js | 18+ (cho web-app) |
| Flutter SDK | 3.11+ |
| SQL Server | SQLEXPRESS |
| Firebase Project | Cần cấu hình `.firebaserc` |
| Gemini API Key | Cần khai báo trong `application.properties` |

### B. Cấu hình application.properties (key fields)

```properties
server.port=8080
spring.datasource.url=jdbc:sqlserver://...\SQLEXPRESS01;databaseName=care_bike
spring.jpa.hibernate.ddl-auto=update
spring.jpa.database-platform=SQLServerDialect
firebase.admin.sdk.path=...serviceAccountKey.json
gemini.api.key=...
```

### C. Trạng thái (Status Enum)

**Appointment Status:**
```
PENDING → CONFIRMED → COMPLETED
    └──────────────→ CANCELLED
```

**Rescue Status:**
```
PENDING → ACCEPTED → COMPLETED
    └────────────────→ CANCELLED
```

**Branch Status:**
```
ACTIVE | INACTIVE
```

**Member Tier:**
```
STANDARD → SILVER → GOLD → PLATINUM
(theo totalSpent tích lũy)
```
