package com.carebike.backend.features.chat.service;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ArrayNode;
import com.fasterxml.jackson.databind.node.ObjectNode;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;

import java.util.List;

@Service
public class GeminiService {

    @Value("${gemini.api.key:}")
    private String apiKey;

    private final RestTemplate restTemplate = new RestTemplate();
    private final ObjectMapper mapper = new ObjectMapper();

    private final com.carebike.backend.features.vehicle.repository.VehicleRepository vehicleRepository;
    private final com.carebike.backend.features.sparepart.repository.SparePartRepository sparePartRepository;
    private final com.carebike.backend.features.maintenance.repository.MaintenanceHistoryRepository maintenanceHistoryRepository;

    public GeminiService(
            com.carebike.backend.features.vehicle.repository.VehicleRepository vehicleRepository,
            com.carebike.backend.features.sparepart.repository.SparePartRepository sparePartRepository,
            com.carebike.backend.features.maintenance.repository.MaintenanceHistoryRepository maintenanceHistoryRepository) {
        this.vehicleRepository = vehicleRepository;
        this.sparePartRepository = sparePartRepository;
        this.maintenanceHistoryRepository = maintenanceHistoryRepository;
    }

    public String chatWithFunctionCalling(Integer customerId, String userMessage) {
        if (apiKey == null || apiKey.trim().isEmpty()) {
            return "Tính năng Chatbot AI chưa được kích hoạt do thiếu API Key.";
        }
        
        try {
            String url = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=" + apiKey;

            // 1. Build Initial Request
            ObjectNode requestNode = buildGeminiRequest(userMessage);
            
            HttpHeaders headers = new HttpHeaders();
            headers.setContentType(MediaType.APPLICATION_JSON);
            
            // 2. Send Request (WITH RETRY LOGIC FOR 503 ERRORS)
            String responseStr = null;
            int maxRetries = 3;
            for (int i = 0; i < maxRetries; i++) {
                try {
                    responseStr = restTemplate.postForObject(url, new HttpEntity<>(requestNode.toString(), headers), String.class);
                    break; // Thành công thì thoát vòng lặp
                } catch (Exception e) {
                    if (i == maxRetries - 1) throw e; // Lần cuối vẫn lỗi thì văng lỗi luôn
                    Thread.sleep(2000); // Đợi 2 giây rồi thử lại
                }
            }
            
            JsonNode responseNode = mapper.readTree(responseStr);

            // 3. Check for Function Call in all parts
            JsonNode candidate = responseNode.path("candidates").path(0);
            JsonNode parts = candidate.path("content").path("parts");

            JsonNode functionCall = null;
            if (parts.isArray()) {
                for (JsonNode part : parts) {
                    if (part.has("functionCall")) {
                        functionCall = part.get("functionCall");
                        break;
                    }
                }
            }

            if (functionCall != null) {
                String functionName = functionCall.get("name").asText();
                JsonNode args = functionCall.get("args");

                // Execute local function
                String functionResult = executeFunction(customerId, functionName, args);

                // 4. Send back the function result to Gemini to get final answer
                ObjectNode followupRequest = buildFollowupRequest(userMessage, functionCall, functionResult);
                
                String finalResponseStr = null;
                for (int i = 0; i < maxRetries; i++) {
                    try {
                        finalResponseStr = restTemplate.postForObject(url, new HttpEntity<>(followupRequest.toString(), headers), String.class);
                        break;
                    } catch (Exception e) {
                        if (i == maxRetries - 1) throw e;
                        Thread.sleep(2000);
                    }
                }
                
                JsonNode finalResponseNode = mapper.readTree(finalResponseStr);
                
                JsonNode finalParts = finalResponseNode.path("candidates").path(0).path("content").path("parts");
                if (finalParts.isArray() && finalParts.size() > 0) {
                    return finalParts.get(0).path("text").asText();
                }
                return "AI không trả lời hợp lệ sau khi gọi hàm.";
            }

            // No function call, just return text
            if (parts.isArray() && parts.size() > 0) {
                return parts.get(0).path("text").asText();
            }
            return "AI không có phản hồi.";

        } catch (Exception e) {
            // Thay vì hiển thị mã lỗi kỹ thuật loằng ngoằng, ta trả về thông báo thân thiện
            return "Hệ thống AI của Google hiện đang tạm thời bị quá tải (Google Server Overload). Anh/Chị vui lòng đợi khoảng 1 phút rồi hỏi lại nhé!";
        }
    }

    private String executeFunction(Integer customerId, String name, JsonNode args) {
        try {
            if ("countCustomerVehicles".equals(name)) {
                int count = vehicleRepository.findByOwnerId(customerId).size();
                return "{\"vehicles_count\": " + count + "}";
            } else if ("getSparePartPrice".equals(name)) {
                String partName = args.get("partName").asText();
                List<com.carebike.backend.features.sparepart.entity.SparePart> parts = sparePartRepository.findAll();
                for (com.carebike.backend.features.sparepart.entity.SparePart p : parts) {
                    if (p.getName().toLowerCase().contains(partName.toLowerCase())) {
                        return "{\"part_name\": \"" + p.getName() + "\", \"price\": " + p.getPrice() + "}";
                    }
                }
                return "{\"error\": \"Không tìm thấy phụ tùng này trong kho\"}";
            } else if ("checkMaintenanceHistory".equals(name)) {
                List<com.carebike.backend.features.maintenance.entity.MaintenanceHistory> list = maintenanceHistoryRepository.findByCustomerIdOrderByServiceDateDesc(customerId);
                if (list.isEmpty()) return "{\"history\": \"Khách hàng chưa có lịch sử sửa chữa nào.\"}";
                
                StringBuilder sb = new StringBuilder("Lịch sử gần đây: ");
                for (int i = 0; i < Math.min(2, list.size()); i++) {
                    sb.append(list.get(i).getServiceDate()).append(" (Chi nhánh: ").append(list.get(i).getBranch().getName()).append(") - Tổng thanh toán: ").append(list.get(i).getTotalCost()).append(" VNĐ. ");
                }
                return "{\"history\": \"" + sb.toString() + "\"}";
            }
        } catch (Exception e) {
            return "{\"error\": \"" + e.getMessage() + "\"}";
        }
        return "{\"error\": \"Unknown function\"}";
    }

    private ObjectNode buildGeminiRequest(String userMessage) {
        ObjectNode root = mapper.createObjectNode();
        
        // System instruction
        ObjectNode systemInstruction = root.putObject("systemInstruction");
        ArrayNode sysParts = systemInstruction.putArray("parts");
        sysParts.addObject().put("text", "Bạn là một nhân viên tư vấn khách hàng AI của ứng dụng CareBike (Cứu hộ xe máy). Hãy xưng hô là 'Dạ', gọi khách hàng là 'Anh/Chị', trả lời ngắn gọn, thân thiện. QUAN TRỌNG: Nếu người dùng hỏi thông tin có thể tra cứu bằng Function (như số xe, giá phụ tùng, lịch sử), BẮT BUỘC PHẢI GỌI FUNCTION NGAY LẬP TỨC để lấy dữ liệu, TUYỆT ĐỐI KHÔNG ĐƯỢC HỎI LẠI ĐỂ XÁC NHẬN. Sau khi có dữ liệu từ Function, hãy trả lời thẳng kết quả cho khách. CỰC KỲ QUAN TRỌNG: Nếu khách hàng nói muốn gọi cứu hộ, hãy trả lời và bắt buộc thêm chuỗi '[ACTION:RESCUE]' vào cuối câu. Nếu khách muốn đặt lịch sửa chữa, hãy trả lời và bắt buộc thêm chuỗi '[ACTION:BOOKING]' vào cuối câu.");

        // Contents
        ArrayNode contents = root.putArray("contents");
        ObjectNode content = contents.addObject();
        content.put("role", "user");
        content.putArray("parts").addObject().put("text", userMessage);

        // Tools
        ArrayNode tools = root.putArray("tools");
        ObjectNode tool = tools.addObject();
        ArrayNode functionDeclarations = tool.putArray("functionDeclarations");

        // Func 1: countCustomerVehicles
        ObjectNode func1 = functionDeclarations.addObject();
        func1.put("name", "countCustomerVehicles");
        func1.put("description", "Dùng để đếm xem khách hàng hiện tại đang sở hữu bao nhiêu chiếc xe trong hệ thống CareBike.");
        
        // Func 2: getSparePartPrice
        ObjectNode func2 = functionDeclarations.addObject();
        func2.put("name", "getSparePartPrice");
        func2.put("description", "Dùng để tra cứu giá tiền của một loại phụ tùng (ví dụ: bugi, lốp, nhông sên dĩa, nhớt).");
        ObjectNode func2Params = func2.putObject("parameters");
        func2Params.put("type", "OBJECT");
        ObjectNode func2Props = func2Params.putObject("properties");
        func2Props.putObject("partName").put("type", "STRING").put("description", "Tên phụ tùng cần tra giá");
        func2Params.putArray("required").add("partName");

        // Func 3: checkMaintenanceHistory
        ObjectNode func3 = functionDeclarations.addObject();
        func3.put("name", "checkMaintenanceHistory");
        func3.put("description", "Dùng để tra cứu lịch sử sửa chữa, cứu hộ gần đây của khách hàng hiện tại.");

        return root;
    }

    private ObjectNode buildFollowupRequest(String userMessage, JsonNode functionCall, String functionResult) throws Exception {
        ObjectNode root = buildGeminiRequest(userMessage); // re-use tools setup
        root.remove("systemInstruction"); // Xóa cái này vì Google Gemini bị bug văng lỗi 503 nếu dính vào followup
        ArrayNode contents = (ArrayNode) root.get("contents");

        // Add Model response (the function call)
        ObjectNode modelContent = contents.addObject();
        modelContent.put("role", "model");
        modelContent.putArray("parts").addObject().set("functionCall", functionCall);

        // Add Function response
        ObjectNode functionContent = contents.addObject();
        functionContent.put("role", "function");
        ObjectNode funcPart = functionContent.putArray("parts").addObject();
        ObjectNode funcRes = funcPart.putObject("functionResponse");
        funcRes.put("name", functionCall.get("name").asText());
        funcRes.set("response", mapper.readTree(functionResult));

        return root;
    }
}
