package com.carebike.backend.features.ai.service;

import com.carebike.backend.features.ai.dto.GeminiRequest;
import com.carebike.backend.features.ai.dto.GeminiResponse;
import com.carebike.backend.features.appointment.entity.Appointment;
import com.carebike.backend.features.appointment.repository.AppointmentRepository;
import com.carebike.backend.features.maintenance.entity.MaintenanceHistory;
import com.carebike.backend.features.maintenance.repository.MaintenanceHistoryRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;

import java.util.List;
import java.util.stream.Collectors;

/**
 * Service chịu trách nhiệm tương tác với Google Gemini 1.5 Flash API.
 * Thực hiện logic RAG (Retrieval-Augmented Generation):
 * 1. Truy xuất lịch sử bảo dưỡng của khách hàng từ cơ sở dữ liệu
 * 2. Xây dựng prompt có bối cảnh (contextual prompt)
 * 3. Gọi Gemini API và trả về phản hồi tư vấn
 */
@Service
public class GeminiApiService {

    private static final Logger logger = LoggerFactory.getLogger(GeminiApiService.class);

    /** URL endpoint của Gemini API, được tiêm từ file application.properties */
    @Value("${gemini.api.url}")
    private String geminiApiUrl;

    /** API Key xác thực với Gemini, được tiêm từ file application.properties */
    @Value("${gemini.api.key}")
    private String geminiApiKey;

    private final RestTemplate restTemplate;
    private final AppointmentRepository appointmentRepository;
    private final MaintenanceHistoryRepository maintenanceHistoryRepository;

    /**
     * Constructor injection — tuân thủ nguyên tắc Dependency Inversion.
     *
     * @param restTemplate                Bean RestTemplate để thực hiện HTTP request
     * @param appointmentRepository       Repository quản lý dữ liệu lịch hẹn
     * @param maintenanceHistoryRepository Repository quản lý dữ liệu lịch sử bảo dưỡng
     */
    public GeminiApiService(RestTemplate restTemplate,
                            AppointmentRepository appointmentRepository,
                            MaintenanceHistoryRepository maintenanceHistoryRepository) {
        this.restTemplate = restTemplate;
        this.appointmentRepository = appointmentRepository;
        this.maintenanceHistoryRepository = maintenanceHistoryRepository;
    }

    /**
     * Xử lý yêu cầu tư vấn bảo dưỡng bằng AI cho một khách hàng cụ thể.
     * Quy trình:
     *  1. Truy xuất lịch sử bảo dưỡng gần nhất (tối đa 3 lần hoàn thành) từ DB
     *  2. Ghép thông tin lịch sử vào prompt theo format chuẩn RAG
     *  3. Gửi prompt đến Gemini API và nhận phản hồi
     *
     * @param customerId Mã định danh của khách hàng cần tư vấn
     * @param userMessage Nội dung câu hỏi hoặc mô tả vấn đề từ khách hàng
     * @return Câu trả lời tư vấn bảo dưỡng từ AI
     * @throws RuntimeException nếu gọi Gemini API thất bại
     */
    public String getAiConsultation(Integer customerId, String userMessage) {
        // Bước 1: Truy xuất lịch sử bảo dưỡng từ cơ sở dữ liệu để làm bối cảnh cho AI
        String maintenanceContext = buildMaintenanceContext(customerId);

        // Bước 2: Xây dựng prompt chuyên nghiệp có bối cảnh lịch sử
        String prompt = buildPrompt(userMessage, maintenanceContext);

        // Bước 3: Gọi Gemini API và trích xuất kết quả phản hồi
        return callGeminiApi(prompt);
    }

    /**
     * Truy xuất và định dạng lịch sử bảo dưỡng của khách hàng.
     * Kết hợp dữ liệu từ 2 nguồn:
     *  - Lịch hẹn đã hoàn thành (Appointment với status = COMPLETED)
     *  - Lịch sử bảo dưỡng chi tiết (MaintenanceHistory)
     * Giới hạn tối đa 3 bản ghi gần nhất từ mỗi nguồn.
     *
     * @param customerId Mã định danh của khách hàng
     * @return Chuỗi văn bản mô tả lịch sử bảo dưỡng, hoặc thông báo nếu chưa có dữ liệu
     */
    private String buildMaintenanceContext(Integer customerId) {
        StringBuilder context = new StringBuilder();

        // Truy xuất danh sách lịch hẹn đã hoàn thành, sắp xếp theo thời gian giảm dần
        List<Appointment> completedAppointments = appointmentRepository
                .findByCustomer_IdOrderByIdDesc(customerId)
                .stream()
                .filter(a -> "COMPLETED".equalsIgnoreCase(a.getStatus()))
                .limit(3)
                .collect(Collectors.toList());

        // Truy xuất lịch sử bảo dưỡng chi tiết, giới hạn 3 bản ghi gần nhất
        List<MaintenanceHistory> maintenanceRecords = maintenanceHistoryRepository
                .findByCustomer_IdOrderByServiceDateDescIdDesc(customerId)
                .stream()
                .limit(3)
                .collect(Collectors.toList());

        // Ghép thông tin lịch hẹn đã hoàn thành vào chuỗi bối cảnh
        if (!completedAppointments.isEmpty()) {
            context.append("=== Lịch hẹn đã hoàn thành ===\n");
            for (int i = 0; i < completedAppointments.size(); i++) {
                Appointment apt = completedAppointments.get(i);
                context.append(String.format("Lần %d: Ngày %s, Chi nhánh: %s, Ghi chú: %s\n",
                        i + 1,
                        apt.getAppointmentDate(),
                        apt.getBranchName() != null ? apt.getBranchName() : "N/A",
                        apt.getNote() != null ? apt.getNote() : "Không có"));
            }
        }

        // Ghép thông tin lịch sử bảo dưỡng chi tiết vào chuỗi bối cảnh
        if (!maintenanceRecords.isEmpty()) {
            context.append("=== Lịch sử bảo dưỡng chi tiết ===\n");
            for (int i = 0; i < maintenanceRecords.size(); i++) {
                MaintenanceHistory record = maintenanceRecords.get(i);
                context.append(String.format(
                        "Lần %d: Ngày %s, Số km: %s, Dịch vụ: %s, Chi phí: %s VNĐ\n",
                        i + 1,
                        record.getServiceDate(),
                        record.getCurrentKm() != null ? record.getCurrentKm() + " km" : "N/A",
                        record.getServiceDetails() != null ? record.getServiceDetails() : "N/A",
                        record.getTotalCost() != null ? record.getTotalCost().toPlainString() : "N/A"));
            }
        }

        // Trả về thông báo mặc định nếu khách hàng chưa có lịch sử nào
        if (context.length() == 0) {
            context.append("Khách hàng này chưa có lịch sử bảo dưỡng nào trong hệ thống.");
        }

        return context.toString();
    }

    /**
     * Xây dựng prompt chuyên nghiệp theo chuẩn RAG.
     * Prompt bao gồm: vai trò AI, câu hỏi khách hàng, lịch sử bảo dưỡng,
     * và hướng dẫn format câu trả lời.
     *
     * @param userMessage Câu hỏi của khách hàng
     * @param maintenanceContext Bối cảnh lịch sử bảo dưỡng đã được định dạng
     * @return Chuỗi prompt hoàn chỉnh gửi đến Gemini
     */
    private String buildPrompt(String userMessage, String maintenanceContext) {
        return String.format(
                "Bạn là chuyên viên tư vấn kỹ thuật xe máy của CareBike — một hệ thống quản lý bảo dưỡng xe máy chuyên nghiệp. " +
                "Hãy tự động nhận diện ngôn ngữ trong câu hỏi của khách hàng và trả lời lại bằng chính ngôn ngữ đó. " +
                "Khách hàng đang hỏi: \"%s\". " +
                "Dưới đây là lịch sử bảo dưỡng của khách hàng này:\n%s\n" +
                "Dựa vào lịch sử này, hãy chẩn đoán vấn đề, tư vấn giải pháp ngắn gọn dưới 100 chữ, " +
                "và luôn kết thúc bằng việc khuyên khách hàng đặt lịch hẹn tại CareBike để kỹ thuật viên kiểm tra trực tiếp.",
                userMessage,
                maintenanceContext
        );
    }

    /**
     * Thực hiện HTTP POST đến Gemini 1.5 Flash API.
     * API Key được truyền qua header "x-goog-api-key" theo chuẩn xác thực của Google.
     *
     * @param prompt Nội dung prompt đã xây dựng hoàn chỉnh
     * @return Nội dung text phản hồi từ mô hình AI
     * @throws RuntimeException nếu gọi API thất bại hoặc response không hợp lệ
     */
    private String callGeminiApi(String prompt) {
        try {
            // Thiết lập HTTP headers theo yêu cầu xác thực của Gemini API
            HttpHeaders headers = new HttpHeaders();
            headers.setContentType(MediaType.APPLICATION_JSON);
            headers.set("x-goog-api-key", geminiApiKey);

            // Tạo request body theo cấu trúc JSON mà Gemini API yêu cầu
            GeminiRequest requestBody = GeminiRequest.fromPrompt(prompt);

            // Đóng gói headers và body vào HttpEntity để gửi đi
            HttpEntity<GeminiRequest> httpEntity = new HttpEntity<>(requestBody, headers);

            // Thực hiện HTTP POST và nhận response
            ResponseEntity<GeminiResponse> responseEntity = restTemplate.postForEntity(
                    geminiApiUrl,
                    httpEntity,
                    GeminiResponse.class
            );

            // Trích xuất nội dung text từ response body
            GeminiResponse geminiResponse = responseEntity.getBody();
            if (geminiResponse == null) {
                throw new RuntimeException("Phản hồi từ Gemini API trả về rỗng.");
            }

            String aiReply = geminiResponse.extractTextResponse();
            if (aiReply.isEmpty()) {
                throw new RuntimeException("Gemini API không trả về nội dung tư vấn.");
            }

            logger.info("Đã nhận phản hồi tư vấn AI thành công cho khách hàng.");
            return aiReply;

        } catch (RuntimeException ex) {
            // Ném lại RuntimeException đã có thông báo rõ ràng
            throw ex;
        } catch (Exception ex) {
            // Bắt mọi lỗi không lường trước khi gọi API bên ngoài
            logger.error("Lỗi khi gọi Gemini API: {}", ex.getMessage(), ex);
            throw new RuntimeException(
                    "Không thể kết nối đến dịch vụ AI. Vui lòng thử lại sau. Chi tiết: " + ex.getMessage()
            );
        }
    }
}
