import 'dart:convert';
import '../core/api_client.dart';

/// Service chịu trách nhiệm kết nối với endpoint AI Tư vấn Bảo dưỡng.
/// Sử dụng ApiClient có sẵn của dự án để đảm bảo tính nhất quán
/// trong việc xác thực JWT Token và xử lý response.
class AiApiService {
  /// Gửi câu hỏi của khách hàng đến AI và nhận phản hồi tư vấn.
  ///
  /// Quy trình:
  /// 1. Đóng gói [customerId] và [message] thành JSON body
  /// 2. Gọi POST đến endpoint `/ai/consult` (đã có JWT Token tự động từ ApiClient)
  /// 3. Bóc tách trường `reply` từ JSON response trả về
  ///
  /// Trả về chuỗi phản hồi tư vấn từ AI.
  /// Ném [Exception] nếu gọi API thất bại hoặc response không hợp lệ.
  static Future<String> askAi(int customerId, String message) async {
    try {
      // Gọi POST request thông qua ApiClient (đã tự đính kèm JWT Token vào Header)
      final response = await ApiClient.post('/ai/consult', {
        'customerId': customerId,
        'message': message,
      });

      // Phân tích response và trích xuất nội dung phản hồi từ AI
      final data = ApiClient.parseResponse(response);

      // Trả về chuỗi reply — là câu trả lời tư vấn của AI
      return data['reply'] ?? 'AI không trả về nội dung tư vấn.';
    } on ApiException catch (e) {
      // Xử lý lỗi HTTP từ phía server (4xx, 5xx)
      throw Exception('Lỗi từ server: ${e.message}');
    } catch (e) {
      // Xử lý các lỗi không lường trước (mất mạng, timeout, JSON sai format...)
      throw Exception('Không thể kết nối đến dịch vụ AI. Vui lòng thử lại sau.');
    }
  }
}
