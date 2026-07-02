package com.carebike.backend.config;

import com.google.firebase.auth.FirebaseAuth;
import com.google.firebase.auth.FirebaseAuthException;
import com.google.firebase.auth.UserRecord;

import com.carebike.backend.features.auth.entity.Role;
import com.carebike.backend.features.auth.entity.User;
import com.carebike.backend.features.auth.repository.RoleRepository;
import com.carebike.backend.features.auth.repository.UserRepository;
import com.carebike.backend.features.branch.entity.Branch;
import com.carebike.backend.features.branch.repository.BranchRepository;
import com.carebike.backend.features.staff.entity.Staff;
import com.carebike.backend.features.staff.entity.Shift;
import com.carebike.backend.features.staff.repository.StaffRepository;
import com.carebike.backend.features.staff.repository.ShiftRepository;
import com.carebike.backend.features.category.entity.Category;
import com.carebike.backend.features.category.repository.CategoryRepository;
import com.carebike.backend.features.sparepart.entity.SparePart;
import com.carebike.backend.features.sparepart.repository.SparePartRepository;
import org.springframework.boot.CommandLineRunner;
import org.springframework.stereotype.Component;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.*;

@Component
public class DataSeeder implements CommandLineRunner {

    private final UserRepository userRepository;
    private final RoleRepository roleRepository;
    private final BranchRepository branchRepository;
    private final StaffRepository staffRepository;
    private final ShiftRepository shiftRepository;
    private final CategoryRepository categoryRepository;
    private final SparePartRepository sparePartRepository;

    public DataSeeder(UserRepository userRepository, RoleRepository roleRepository,
                      BranchRepository branchRepository, StaffRepository staffRepository,
                      ShiftRepository shiftRepository, CategoryRepository categoryRepository,
                      SparePartRepository sparePartRepository) {
        this.userRepository = userRepository;
        this.roleRepository = roleRepository;
        this.branchRepository = branchRepository;
        this.staffRepository = staffRepository;
        this.shiftRepository = shiftRepository;
        this.categoryRepository = categoryRepository;
        this.sparePartRepository = sparePartRepository;
    }

    @Override
    public void run(String... args) throws Exception {
        // 1. TỰ ĐỘNG TẠO 3 QUYỀN (ROLES) NẾU BẢNG ROLES TRỐNG
        if (roleRepository.count() == 0) {
            Role adminRole = new Role(); adminRole.setRoleName("ADMIN"); roleRepository.save(adminRole);
            Role branchRole = new Role(); branchRole.setRoleName("BRANCH"); roleRepository.save(branchRole);
            Role customerRole = new Role(); customerRole.setRoleName("CUSTOMER"); roleRepository.save(customerRole);
            System.out.println("✅ Đã khởi tạo 3 Roles mặc định vào Database.");
        }

        // 2. TỰ ĐỘNG TẠO TÀI KHOẢN SUPER ADMIN
        String adminEmail = "admin@carebike.com";
        if (!userRepository.existsByEmail(adminEmail)) {
            User admin = new User();
            admin.setEmail(adminEmail);
            admin.setFullName("Super Admin CareBike");
            admin.setFirebaseUid("UnmBZJtdaWUsE3UcZ1QrDYBtYXp1"); 
            
            // Gán quyền ADMIN (Role ID = 1)
            Role adminRole = roleRepository.findById(1).orElseThrow();
            admin.setRole(adminRole);
            
            userRepository.save(admin);
            System.out.println("Đã khởi tạo tài khoản Super Admin thành công!");
        }

        // 3. TỰ ĐỘNG TẠO 10 CHI NHÁNH & ACCOUNT QUẢN LÝ
        seedBranches();

        // 4. TỰ ĐỘNG TẠO NHÂN VIÊN VÀ PHÂN CA
        seedStaffAndShifts();

        // 5. TỰ ĐỘNG TẠO DANH MỤC & PHỤ TÙNG
        // Đã tắt để người dùng tự thêm danh mục riêng mà không bị trùng lặp
        // seedCategoriesAndSpareParts();

        // 6. TỰ ĐỘNG TẠO KHÁCH HÀNG MẪU
        seedCustomers();
    }

    private void seedBranches() {

        Role branchRole = roleRepository.findByRoleName("BRANCH")
                .orElseThrow(() -> new RuntimeException("Không tìm thấy BRANCH role"));

        // Dữ liệu 10 quận trung tâm TP.HCM
        String[][] branchData = {
            {"Care Bike Q1",  "123 Le Loi, District 1, HCMC",          "0901000001", "10.77620000", "106.69990000"},
            {"Care Bike Q2",  "456 Nguyen Thi Dinh, Thu Duc City, HCMC", "0901000002", "10.78750000", "106.74810000"},
            {"Care Bike Q3",  "78 Vo Van Tan, District 3, HCMC",        "0901000003", "10.78100000", "106.68900000"},
            {"Care Bike Q4",  "200 Hoang Dieu, District 4, HCMC",       "0901000004", "10.75800000", "106.70100000"},
            {"Care Bike Q5",  "150 Tran Hung Dao, District 5, HCMC",    "0901000005", "10.75400000", "106.67300000"},
            {"Care Bike Q6",  "300 Hau Giang, District 6, HCMC",        "0901000006", "10.74700000", "106.64100000"},
            {"Care Bike Q7",  "88 Nguyen Thi Thap, District 7, HCMC",   "0901000007", "10.73380000", "106.72200000"},
            {"Care Bike Q8",  "55 Pham The Hien, District 8, HCMC",     "0901000008", "10.74000000", "106.66200000"},
            {"Care Bike Q9",  "101 Le Van Viet, Thu Duc City, HCMC",  "0901000009", "10.84200000", "106.78100000"},
            {"Care Bike Q10", "500 Cach Mang Thang 8, District 10, HCMC", "0901000010", "10.77100000", "106.66700000"},
        };

        for (int i = 0; i < branchData.length; i++) {
            String[] data = branchData[i];
            String branchEmail = "carebike_q" + (i + 1) + "@carebike.com";
            String managerName = "Manager " + data[0];
            String phone = data[2];
            String firebaseUid = null;

            // 1. Tạo hoặc lấy tài khoản từ Firebase Auth
            try {
                UserRecord userByEmail = FirebaseAuth.getInstance().getUserByEmail(branchEmail);
                firebaseUid = userByEmail.getUid();
                System.out.println("Firebase user already exists: " + branchEmail + " (UID: " + firebaseUid + ")");
            } catch (FirebaseAuthException e) {
                if (String.valueOf(e.getErrorCode()).equals("user-not-found") || e.getMessage().contains("No user record found") || e.getMessage().contains("user-not-found")) {
                    try {
                        UserRecord.CreateRequest req = new UserRecord.CreateRequest()
                                .setEmail(branchEmail)
                                .setPassword("123456")
                                .setDisplayName(managerName);
                        UserRecord newFbUser = FirebaseAuth.getInstance().createUser(req);
                        firebaseUid = newFbUser.getUid();
                        System.out.println("Created Firebase user: " + branchEmail);
                    } catch (FirebaseAuthException ex) {
                        System.err.println("Không thể tạo Firebase User cho " + branchEmail + ": " + ex.getMessage());
                        continue; // Bỏ qua nếu lỗi
                    }
                } else {
                    System.err.println("Lỗi khi kiểm tra Firebase User: " + e.getMessage());
                    continue; // Lỗi khác, bỏ qua
                }
            }

            // 2. Tạo tài khoản quản lý chi nhánh trong DB nếu chưa có
            if (firebaseUid != null) {
                User manager = null;
                Optional<User> existingUser = userRepository.findByFirebaseUid(firebaseUid);
                if (existingUser.isEmpty()) {
                    manager = new User();
                    manager.setEmail(branchEmail);
                    manager.setFullName(managerName);
                    manager.setPhone(phone);
                    manager.setFirebaseUid(firebaseUid);
                    manager.setRole(branchRole);
                    manager.setIsActive(true);
                    manager.setCreatedAt(Instant.now());
                    manager = userRepository.save(manager);
                } else {
                    manager = existingUser.get();
                }

                // 3. Tạo hoặc Cập nhật chi nhánh
                final Integer managerId = manager.getId();
                final String branchName = data[0];
                Branch branch = branchRepository.findAll().stream()
                        .filter(b -> b.getManager() != null && b.getManager().getId().equals(managerId))
                        .findFirst().orElse(null);
                
                if (branch == null) {
                    branch = new Branch();
                    branch.setCreatedAt(Instant.now());
                }
                branch.setName(branchName);
                branch.setAddress(data[1]);
                branch.setPhone(phone);
                branch.setLatitude(new BigDecimal(data[3]));
                branch.setLongitude(new BigDecimal(data[4]));
                branch.setManager(manager);
                branch.setStatus("ACTIVE");
                branchRepository.save(branch);
            }
        }

        System.out.println("✅ Đã khởi tạo 10 Chi nhánh + 10 Account quản lý (kết nối Firebase).");
    }

    private void seedStaffAndShifts() {
        if (staffRepository.count() > 0) return; // Đã có dữ liệu

        List<Branch> branches = branchRepository.findAll();
        if (branches.isEmpty()) return;

        // Danh sách 100 tên tiếng Anh ngẫu nhiên
        String[] firstNames = {"James", "John", "Robert", "Michael", "David", "William", "Richard", "Joseph", "Thomas", "Christopher",
                "Daniel", "Matthew", "Anthony", "Mark", "Andrew", "Steven", "Paul", "Joshua", "Kevin", "Brian",
                "George", "Edward", "Ronald", "Timothy", "Jason", "Jeffrey", "Ryan", "Jacob", "Gary", "Nicholas",
                "Eric", "Jonathan", "Stephen", "Larry", "Justin", "Scott", "Brandon", "Benjamin", "Samuel", "Patrick",
                "Alexander", "Frank", "Raymond", "Jack", "Dennis", "Jerry", "Tyler", "Aaron", "Nathan", "Henry",
                "Douglas", "Peter", "Adam", "Zachary", "Walter", "Kyle", "Harold", "Carl", "Arthur", "Gerald",
                "Roger", "Keith", "Jeremy", "Terry", "Lawrence", "Jesse", "Bryan", "Joe", "Jordan", "Billy",
                "Albert", "Dylan", "Bruce", "Willie", "Ralph", "Gabriel", "Roy", "Eugene", "Russell", "Randy",
                "Philip", "Vincent", "Bobby", "Louis", "Johnny", "Russell", "Wayne", "Elijah", "Liam", "Noah",
                "Oliver", "Lucas", "Mason", "Logan", "Ethan", "Aiden", "Jackson", "Sebastian", "Caleb", "Owen"};

        String[] lastNames = {"Smith", "Johnson", "Williams", "Brown", "Jones", "Garcia", "Miller", "Davis", "Wilson", "Taylor"};

        // Variables removed to fix unused warnings

        Random random = new Random(42);
        int staffCodeCounter = 1;

        for (Branch branch : branches) {
            List<Staff> branchStaffs = new ArrayList<>();
            List<Shift> branchShifts = new ArrayList<>();

            // Tạo 10 nhân viên cho mỗi chi nhánh
            for (int j = 0; j < 10; j++) {
                String staffCode = String.format("CBS-%04d", staffCodeCounter++);
                String fullName = firstNames[random.nextInt(firstNames.length)] + " " + lastNames[random.nextInt(lastNames.length)];
                String phone = "09" + String.format("%08d", 10000000 + random.nextInt(89999999));

                Staff staff = Staff.builder()
                        .staffCode(staffCode)
                        .fullName(fullName)
                        .phone(phone)
                        .branch(branch)
                        .build();
                staff = staffRepository.save(staff);
                branchStaffs.add(staff);
            }

            // Phân ca tự động xoay vòng cho từng ngày trong tuần này
            java.time.LocalDate startOfWeek = java.time.LocalDate.now().with(java.time.DayOfWeek.MONDAY);
            for (int i = 0; i < 7; i++) {
                java.time.LocalDate currentDay = startOfWeek.plusDays(i);

                // Ca Sáng: 4 nhân viên
                for (int count = 0; count < 4; count++) {
                    int s = (i * 4 + count) % 10;
                    Shift shift = Shift.builder()
                            .staff(branchStaffs.get(s))
                            .shiftDate(currentDay)
                            .shiftType("MORNING")
                            .branch(branch)
                            .build();
                    branchShifts.add(shift);
                }
                // Ca Chiều: 4 nhân viên
                for (int count = 0; count < 4; count++) {
                    int s = (i * 4 + 4 + count) % 10;
                    Shift shift = Shift.builder()
                            .staff(branchStaffs.get(s))
                            .shiftDate(currentDay)
                            .shiftType("AFTERNOON")
                            .branch(branch)
                            .build();
                    branchShifts.add(shift);
                }
                // Ca Đêm: 2 nhân viên
                for (int count = 0; count < 2; count++) {
                    int s = (i * 4 + 8 + count) % 10;
                    Shift shift = Shift.builder()
                            .staff(branchStaffs.get(s))
                            .shiftDate(currentDay)
                            .shiftType("NIGHT")
                            .branch(branch)
                            .build();
                    branchShifts.add(shift);
                }
            }
            shiftRepository.saveAll(branchShifts);
        }

        System.out.println("✅ Đã khởi tạo 100 Nhân viên (10 NV/chi nhánh) + Phân ca mặc định.");
    }

    @SuppressWarnings("unused")
    private void seedCategoriesAndSpareParts() {
        if (categoryRepository.count() > 0) return;

        Category c1 = Category.builder().name("Tires & Tubes").description("Replacement tires and inner tubes").build();
        Category c2 = Category.builder().name("Brakes").description("Brake pads and cables").build();
        Category c3 = Category.builder().name("Drivetrain").description("Chains, cassettes, and pedals").build();
        categoryRepository.saveAll(List.of(c1, c2, c3));

        List<SparePart> parts = new ArrayList<>();
        parts.add(SparePart.builder().name("Maxxis Inner Tube").price(new BigDecimal("150000")).category(c1).build());
        parts.add(SparePart.builder().name("Michelin Tire 29x2.1").price(new BigDecimal("450000")).category(c1).build());
        parts.add(SparePart.builder().name("Shimano Brake Pads").price(new BigDecimal("200000")).category(c2).build());
        parts.add(SparePart.builder().name("Brake Cable Inner").price(new BigDecimal("50000")).category(c2).build());
        parts.add(SparePart.builder().name("KMC 11-Speed Chain").price(new BigDecimal("350000")).category(c3).build());
        parts.add(SparePart.builder().name("Shimano Cassette").price(new BigDecimal("600000")).category(c3).build());
        parts.add(SparePart.builder().name("Standard Pedals").price(new BigDecimal("120000")).category(c3).build());
        
        sparePartRepository.saveAll(parts);
        System.out.println("✅ Đã khởi tạo Danh mục và Phụ tùng mặc định.");
    }

    private void seedCustomers() {
        Role customerRole = roleRepository.findByRoleName("CUSTOMER").orElse(null);
        if (customerRole == null) return;

        long currentCustomers = userRepository.findAll().stream()
                .filter(u -> "CUSTOMER".equals(u.getRole().getRoleName())).count();
        
        if (currentCustomers > 0) return;

        List<User> customers = new ArrayList<>();
        String[] firstNames = {"Alice", "Bob", "Charlie", "Diana", "Eve", "Frank", "Grace", "Heidi", "Ivan", "Judy"};
        String[] lastNames = {"Smith", "Johnson", "Williams", "Brown", "Jones", "Garcia", "Miller", "Davis", "Wilson", "Taylor"};

        for (int i = 0; i < 10; i++) {
            String email = "customer" + (i + 1) + "@example.com";
            String fullName = firstNames[i] + " " + lastNames[i];
            String phone = "09" + String.format("%08d", 90000000 + i);
            String firebaseUid = null;

            try {
                UserRecord userByEmail = FirebaseAuth.getInstance().getUserByEmail(email);
                firebaseUid = userByEmail.getUid();
            } catch (FirebaseAuthException e) {
                if (String.valueOf(e.getErrorCode()).equals("user-not-found") || e.getMessage().contains("No user record found") || e.getMessage().contains("user-not-found")) {
                    try {
                        UserRecord.CreateRequest req = new UserRecord.CreateRequest()
                                .setEmail(email)
                                .setPassword("123456")
                                .setDisplayName(fullName);
                        UserRecord userRecord = FirebaseAuth.getInstance().createUser(req);
                        firebaseUid = userRecord.getUid();
                    } catch (FirebaseAuthException ex) {
                        System.err.println("Lỗi tạo user Firebase: " + ex.getMessage());
                    }
                }
            }

            if (firebaseUid == null) {
                firebaseUid = "dummy_firebase_uid_customer_" + i;
            }

            User c = new User();
            c.setEmail(email);
            c.setFullName(fullName);
            c.setPhone(phone);
            c.setFirebaseUid(firebaseUid);
            c.setRole(customerRole);
            c.setIsActive(true);
            c.setCreatedAt(Instant.now());
            customers.add(c);
        }
        userRepository.saveAll(customers);
        System.out.println("✅ Đã khởi tạo 10 Tài khoản Khách hàng mẫu.");
    }
}