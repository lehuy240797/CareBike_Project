import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/ai_api_service.dart';

/// ============================================================================
/// AI ASSISTANT BOTTOM SHEET — Giao diện chat tư vấn bảo dưỡng AI
/// ============================================================================
/// Widget trượt từ dưới lên (Bottom Sheet) cho phép khách hàng trò chuyện
/// với trợ lý AI của CareBike. Không làm gián đoạn luồng sử dụng chính.
///
/// Kiến trúc giao diện:
///   ┌──────────────────────────────┐
///   │  Header: Tiêu đề + Nút (X)  │
///   ├──────────────────────────────┤
///   │  Body: ListView bong bóng    │
///   │  chat (User bên phải,        │
///   │  AI bên trái)                │
///   ├──────────────────────────────┤
///   │  Bottom: TextField + Send    │
///   └──────────────────────────────┘
///
/// Luồng xử lý:
///   1. User nhập câu hỏi → Bấm gửi
///   2. Hiển thị tin nhắn user ngay lập tức lên ListView
///   3. Hiện hiệu ứng "AI đang phân tích..." (loading indicator)
///   4. Gọi API `/ai/consult` qua AiApiService
///   5. Nhận kết quả → Hiển thị bong bóng chat AI
/// ============================================================================
class AiAssistantBottomSheet extends StatefulWidget {
  const AiAssistantBottomSheet({super.key});

  /// Hàm tĩnh giúp mở Bottom Sheet AI ở bất kỳ đâu chỉ với 1 dòng code.
  /// Sử dụng pattern tương tự RescueBottomSheet để đảm bảo tính nhất quán.
  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Cho phép Bottom Sheet chiếm phần lớn màn hình
      backgroundColor: Colors.transparent,
      builder: (_) => const AiAssistantBottomSheet(),
    );
  }

  @override
  State<AiAssistantBottomSheet> createState() => _AiAssistantBottomSheetState();
}

class _AiAssistantBottomSheetState extends State<AiAssistantBottomSheet> {
  /// Danh sách các tin nhắn trong cuộc hội thoại.
  /// Mỗi phần tử là Map chứa: 'text' (nội dung), 'isUser' (true/false), 'isLoading' (đang chờ AI).
  final List<Map<String, dynamic>> _messages = [];

  /// Controller quản lý nội dung TextField nhập tin nhắn
  final TextEditingController _inputController = TextEditingController();

  /// Controller cuộn tự động ListView xuống cuối khi có tin nhắn mới
  final ScrollController _scrollController = ScrollController();

  /// Cờ trạng thái: true khi đang chờ phản hồi từ AI (ngăn gửi tin trùng lặp)
  bool _isWaitingAi = false;

  @override
  void initState() {
    super.initState();
    // Thêm tin nhắn chào mừng mặc định khi khách hàng mở Bottom Sheet
    _messages.add({
      'text': 'Xin chào! Tôi là trợ lý AI của CareBike 🏍️\n\n'
          'Tôi có thể giúp bạn:\n'
          '• Chẩn đoán vấn đề xe máy\n'
          '• Tư vấn lịch bảo dưỡng\n'
          '• Giải đáp thắc mắc kỹ thuật\n\n'
          'Hãy mô tả vấn đề bạn đang gặp nhé!',
      'isUser': false,
      'isLoading': false,
    });
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Cuộn ListView xuống cuối cùng sau khi thêm tin nhắn mới.
  /// Sử dụng delay nhỏ để đảm bảo ListView đã render xong frame mới.
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// Xử lý logic khi khách hàng bấm nút gửi tin nhắn.
  /// Quy trình:
  ///   1. Lấy nội dung từ TextField và xóa trắng ô nhập
  ///   2. Thêm tin nhắn user vào danh sách (hiển thị bên phải)
  ///   3. Thêm placeholder loading cho AI (hiển thị hiệu ứng "đang phân tích")
  ///   4. Gọi AiApiService để lấy phản hồi từ Gemini AI
  ///   5. Thay thế placeholder bằng nội dung phản hồi thực tế
  Future<void> _sendMessage() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _isWaitingAi) return;

    // Lấy customerId từ AuthProvider (tương tự cách các Widget khác sử dụng)
    final user = context.read<AuthProvider>().mysqlUser;
    final customerId = user?['userId'] ?? user?['id'];

    if (customerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không xác định được tài khoản. Vui lòng đăng nhập lại.')),
      );
      return;
    }

    // Bước 1: Xóa nội dung TextField và cập nhật trạng thái
    _inputController.clear();
    setState(() {
      _isWaitingAi = true;

      // Bước 2: Thêm tin nhắn của khách hàng (hiển thị bên phải, màu Primary)
      _messages.add({
        'text': text,
        'isUser': true,
        'isLoading': false,
      });

      // Bước 3: Thêm placeholder "AI đang phân tích" (hiển thị hiệu ứng loading)
      _messages.add({
        'text': '',
        'isUser': false,
        'isLoading': true,
      });
    });
    _scrollToBottom();

    try {
      // Bước 4: Gọi API tư vấn AI qua Service
      final reply = await AiApiService.askAi(customerId, text);

      if (!mounted) return;
      setState(() {
        // Bước 5: Thay thế placeholder loading bằng nội dung phản hồi thực tế
        _messages.removeLast(); // Xóa placeholder loading
        _messages.add({
          'text': reply,
          'isUser': false,
          'isLoading': false,
        });
        _isWaitingAi = false;
      });
    } catch (e) {
      // Xử lý lỗi: Thay placeholder bằng thông báo lỗi thân thiện
      if (!mounted) return;
      setState(() {
        _messages.removeLast();
        _messages.add({
          'text': 'Xin lỗi, tôi không thể xử lý yêu cầu lúc này. Vui lòng thử lại sau. 🔧',
          'isUser': false,
          'isLoading': false,
        });
        _isWaitingAi = false;
      });
    }
    _scrollToBottom();
  }

  // ============================================================================
  // XÂY DỰNG GIAO DIỆN (BUILD METHODS)
  // ============================================================================

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    // Container chính của Bottom Sheet, chiếm 85% chiều cao màn hình
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      padding: EdgeInsets.only(bottom: bottomInset), // Đẩy lên khi bàn phím mở
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // === HEADER: Thanh tiêu đề + Nút đóng ===
          _buildHeader(scheme),

          // === BODY: Danh sách bong bóng chat ===
          Expanded(child: _buildChatBody(scheme)),

          // === BOTTOM: Ô nhập tin nhắn + Nút gửi ===
          _buildInputArea(scheme),
        ],
      ),
    );
  }

  /// Xây dựng Header của Bottom Sheet.
  /// Bao gồm: thanh kéo (drag handle), tiêu đề, và nút đóng (X).
  Widget _buildHeader(ColorScheme scheme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 8, 12),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Thanh kéo (Drag handle) — chuẩn Material Design
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          Row(
            children: [
              // Icon robot AI với nền gradient
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [scheme.primary, scheme.tertiary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              // Tiêu đề và mô tả trạng thái
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '🤖 Trợ lý AI CareBike',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Đang hoạt động',
                          style: TextStyle(
                            fontSize: 12,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Nút đóng Bottom Sheet
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.close_rounded, color: scheme.onSurfaceVariant),
                tooltip: 'Đóng',
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Xây dựng Body chứa danh sách bong bóng chat.
  /// Sử dụng ListView.builder để render hiệu quả khi có nhiều tin nhắn.
  Widget _buildChatBody(ColorScheme scheme) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final msg = _messages[index];
        final isUser = msg['isUser'] as bool;
        final isLoading = msg['isLoading'] as bool;

        return _buildChatBubble(
          text: msg['text'] as String,
          isUser: isUser,
          isLoading: isLoading,
          scheme: scheme,
        );
      },
    );
  }

  /// Xây dựng một bong bóng chat (Chat Bubble).
  /// - Tin nhắn User: Nằm bên phải, nền màu Primary, chữ trắng.
  /// - Tin nhắn AI: Nằm bên trái, nền xám nhạt, chữ đen.
  /// - Trạng thái loading: Hiển thị hiệu ứng "AI đang phân tích dữ liệu..."
  Widget _buildChatBubble({
    required String text,
    required bool isUser,
    required bool isLoading,
    required ColorScheme scheme,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Avatar AI (chỉ hiển thị cho tin nhắn AI)
          if (!isUser)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [scheme.primary, scheme.tertiary],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 16),
            ),

          // Bong bóng chat (giới hạn chiều rộng tối đa 75% màn hình)
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isUser
                    ? scheme.primary                       // Nền Primary cho tin nhắn User
                    : scheme.surfaceContainerHighest,      // Nền xám nhạt cho tin nhắn AI
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  // Bo góc dưới khác nhau để phân biệt chiều hướng tin nhắn
                  bottomLeft: Radius.circular(isUser ? 18 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: scheme.shadow.withValues(alpha: 0.06),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: isLoading
                  ? _buildLoadingIndicator(scheme) // Hiệu ứng loading khi chờ AI phản hồi
                  : Text(
                      text,
                      style: TextStyle(
                        color: isUser ? scheme.onPrimary : scheme.onSurface,
                        fontSize: 14.5,
                        height: 1.45,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  /// Xây dựng hiệu ứng "AI đang phân tích dữ liệu..."
  /// Sử dụng CircularProgressIndicator kết hợp với text mô tả.
  Widget _buildLoadingIndicator(ColorScheme scheme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: scheme.primary,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          'AI đang phân tích dữ liệu...',
          style: TextStyle(
            color: scheme.onSurfaceVariant,
            fontSize: 13,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  /// Xây dựng khu vực nhập tin nhắn ở đáy Bottom Sheet.
  /// Bao gồm: TextField nhập nội dung và nút gửi (Icon mũi tên).
  Widget _buildInputArea(ColorScheme scheme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: scheme.surface,
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // TextField nhập nội dung câu hỏi
            Expanded(
              child: TextField(
                controller: _inputController,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(), // Gửi khi bấm Enter trên bàn phím
                maxLines: 3,
                minLines: 1,
                decoration: InputDecoration(
                  hintText: 'Nhập câu hỏi về xe của bạn...',
                  hintStyle: TextStyle(color: scheme.onSurfaceVariant.withValues(alpha: 0.6)),
                  filled: true,
                  fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(color: scheme.primary, width: 1.5),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Nút gửi tin nhắn (Icon mũi tên)
            // Chỉ kích hoạt khi không đang chờ phản hồi AI
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _isWaitingAi
                      ? [Colors.grey, Colors.grey]
                      : [scheme.primary, scheme.tertiary],
                ),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                onPressed: _isWaitingAi ? null : _sendMessage,
                icon: Icon(
                  Icons.send_rounded,
                  color: _isWaitingAi ? Colors.white54 : Colors.white,
                  size: 20,
                ),
                tooltip: 'Gửi',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
