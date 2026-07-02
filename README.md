# CareBike Project

## 1. Giới thiệu
Dự án CareBike bao gồm 3 phần:
- **Backend (Java Spring Boot)**: Chứa logic xử lý, API và quản lý database.
- **Frontend Web (React/TypeScript)**: Trang web quản trị.
- **Mobile App (Flutter)**: Ứng dụng di động dành cho người dùng.

## 2. Hướng dẫn cho người tải source code (Teammates)

### Yêu cầu hệ thống
- SQL Server
- Java 17+
- Node.js (cho Web App)
- Flutter SDK (cho Mobile App)

### Bước 1: Khởi tạo Database (Cực kỳ quan trọng)
Để có đầy đủ dữ liệu (tài khoản, danh mục, sản phẩm) giống hệt với người tạo ra project, bạn cần chạy script database đã được cung cấp.

1. Mở **SQL Server Management Studio (SSMS)**.
2. Tạo một database mới có tên là `care_bike` (hoặc tên theo script cấu hình).
3. Mở file `database/care_bike_db.sql` (bạn hãy yêu cầu người up code tạo ra file này theo hướng dẫn bên dưới).
4. Nhấn **Execute** để chạy toàn bộ file SQL này. Lúc này database của bạn sẽ có đầy đủ các bảng và dữ liệu.

### Bước 2: Khởi chạy Backend (Java Spring Boot)
1. Mở thư mục `backend-java` trong IntelliJ IDEA hoặc IDE hỗ trợ Java.
2. Mở file `src/main/resources/application.properties` và sửa lại `spring.datasource.url`, `username`, `password` cho đúng với SQL Server ở máy bạn.
3. Chạy project. Backend sẽ tự động load ảnh sản phẩm từ thư mục `uploads/images/` đã được push lên cùng source code.
4. **Lưu ý quan trọng về bảo mật (Firebase/Secret keys):** Những file bảo mật như `carebike-firebase-adminsdk.json` (nếu có) thường không được đẩy lên GitHub. Hãy liên hệ người tạo dự án để lấy file này và đặt đúng vị trí.

### Bước 3: Khởi chạy Web App (React)
1. Mở terminal, trỏ vào thư mục `web-app`.
2. Chạy lệnh: `npm install` (để cài đặt thư viện).
3. Chạy lệnh: `npm run dev` (để khởi chạy trang web).

### Bước 4: Khởi chạy Mobile App (Flutter)
1. Mở thư mục `mobile_app` bằng VS Code hoặc Android Studio.
2. Chạy lệnh: `flutter pub get`
3. Chạy app trên máy ảo hoặc thiết bị thật.

---

## 3. Dành cho người đẩy code lên GitHub (Bạn)

Để nhóm của bạn có thể lấy code về và chạy được đầy đủ dữ liệu như máy của bạn, bạn **BẮT BUỘC** phải làm các bước sau trước khi push lên GitHub:

### Cách xuất (Export) Database ra file SQL có kèm dữ liệu
Vì bạn đang dùng SQL Server, bạn phải xuất schema và data ra thành một file `.sql`.

1. Mở **SQL Server Management Studio (SSMS)**.
2. Click chuột phải vào database `care_bike` > Chọn **Tasks** > **Generate Scripts...**
3. Bấm **Next**. Ở màn hình "Choose Objects", chọn **Script entire database and all database objects**. Bấm **Next**.
4. Ở màn hình "Set Scripting Options":
   - Chọn **Save as script file** và chọn đường dẫn lưu file (hãy tạo thư mục `database/` trong thư mục gốc project của bạn và lưu vào đó, ví dụ `database/care_bike_db.sql`).
   - **QUAN TRỌNG:** Bấm vào nút **Advanced**. Kéo xuống tìm mục **Types of data to script**, đổi từ `Schema only` thành **`Schema and data`**. Bấm OK.
5. Bấm Next > Next > Finish.
6. Khi đó bạn sẽ có một file `.sql` chứa toàn bộ cấu trúc bảng và dữ liệu (bao gồm cả tài khoản, sản phẩm bạn đã nhập). Bạn hãy add file này vào Git và push lên.

### Về vấn đề hình ảnh (Đã được tự động xử lý)
Tôi đã giúp bạn sửa lại đường dẫn hình ảnh trong code backend:
- Đổi từ đường dẫn cứng `E:/HK4_Aptech/project/CareBike_Project/Images/` sang thư mục tương đối `uploads/images/` bên trong `backend-java`.
- Tôi cũng đã copy toàn bộ ảnh hiện tại của bạn vào `backend-java/uploads/images/`.
- Khi bạn push code lên GitHub, thư mục này sẽ được đẩy lên. Các bạn trong nhóm sau khi clone về sẽ **tự động** có tất cả hình ảnh, và code sẽ tự động đọc từ thư mục này ở bất kì máy nào (không còn phụ thuộc vào ổ E: nữa).

### Tổng kết
- Chạy lệnh git commit và push các thay đổi mới nhất (đặc biệt là code đã sửa ở backend và thư mục `uploads/images`).
- Xuất file `.sql` như hướng dẫn trên, bỏ vào thư mục `database`, commit và push lên.
- Bạn của bạn chỉ cần clone về, chạy file SQL, là mọi thứ sẽ y hệt như trên máy bạn!
