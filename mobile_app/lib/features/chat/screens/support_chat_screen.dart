import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:mobile_app/core/network/api_client.dart';
import 'package:mobile_app/core/theme/theme.dart';
import 'package:mobile_app/features/auth/providers/auth_provider.dart';
import 'package:mobile_app/features/rescue/widgets/rescue_bottom_sheet.dart';

/// AI-powered motorcycle maintenance consultant chat screen.
/// Connects to POST /api/ai/consult on the backend (Gemini API).
class SupportChatScreen extends StatefulWidget {
  const SupportChatScreen({super.key});

  @override
  State<SupportChatScreen> createState() => _SupportChatScreenState();
}

class _ChatMessage {
  final String text;
  final bool fromUser;
  final String time;
  final bool hasRescue;
  final bool hasBooking;
  const _ChatMessage(this.text, this.fromUser, this.time, {this.hasRescue = false, this.hasBooking = false});
}

class _SupportChatScreenState extends State<SupportChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();

  final List<_ChatMessage> _messages = [];
  bool _botTyping = false;

  @override
  void initState() {
    super.initState();
    // Welcome message from AI
    _messages.add(const _ChatMessage(
      'Hi 👋 I\'m the CareBike AI Assistant — your smart motorcycle care advisor.\n\nAsk me anything about maintenance, troubleshooting, or book a service!',
      false,
      '',
    ));
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent + 120,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  String _now() {
    final t = TimeOfDay.now();
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  void _send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _botTyping) return;

    // Add user message
    setState(() {
      _messages.add(_ChatMessage(trimmed, true, _now()));
      _input.clear();
      _botTyping = true;
    });
    _scrollToEnd();

    // Get customer ID from auth
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final customerId = auth.mysqlUser?['userId'];

    if (customerId == null) {
      setState(() {
        _botTyping = false;
        _messages.add(_ChatMessage(
          'Unable to identify your account. Please log in again.',
          false, _now(),
        ));
      });
      _scrollToEnd();
      return;
    }

    try {
      // Call backend AI endpoint: POST /api/ai/consult
      final response = await ApiClient.post('/ai/consult', {
        'customerId': customerId,
        'message': trimmed,
      });
      final data = ApiClient.parseResponse(response);

      String reply = data['reply']?.toString() ?? 'Sorry, no response received.';

      // Parse action tags from AI reply
      bool hasRescue = false;
      bool hasBooking = false;
      if (reply.contains('[ACTION:RESCUE]')) {
        hasRescue = true;
        reply = reply.replaceAll('[ACTION:RESCUE]', '').trim();
      }
      if (reply.contains('[ACTION:BOOKING]')) {
        hasBooking = true;
        reply = reply.replaceAll('[ACTION:BOOKING]', '').trim();
      }

      if (!mounted) return;
      setState(() {
        _botTyping = false;
        _messages.add(_ChatMessage(reply, false, _now(),
            hasRescue: hasRescue, hasBooking: hasBooking));
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _botTyping = false;
        _messages.add(_ChatMessage(
          'Sorry, I cannot connect to the AI service right now. Please try again later. 🔧',
          false, _now(),
        ));
      });
    }
    _scrollToEnd();
  }

  // ── Suggested quick questions ────────────────────────────────────────────
  static const _suggestions = [
    '🛵 When should I change my oil?',
    '🔧 My brake feels soft',
    '📅 Book a checkup',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Column(
        children: [
          _header(),
          Expanded(
            child: ListView(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
              children: [
                _dayDivider('Today'),
                const SizedBox(height: 14),
                for (final m in _messages) ...[
                  m.fromUser ? _userBubble(m) : _botBubble(m),
                  const SizedBox(height: 14),
                ],
                if (_botTyping) ...[
                  _typingBubble(),
                  const SizedBox(height: 14),
                ],
                // Show suggestions only if there's just the welcome message
                if (_messages.length == 1 && !_botTyping) _suggestionsRow(),
              ],
            ),
          ),
          _inputBar(),
        ],
      ),
    );
  }

  // ── Header ───────────────────────────────────────────────────────────────
  Widget _header() {
    final topInset = MediaQuery.of(context).padding.top;
    return Container(
      padding: EdgeInsets.fromLTRB(12, topInset + 8, 16, 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFFB923C), Color(0xFFF97316), Color(0xFFEA580C)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(26)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            splashRadius: 22,
          ),
          Container(
            width: 42, height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.22), shape: BoxShape.circle),
            child: const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('CareBike AI', style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white)),
                Text('Maintenance Advisor', style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.8))),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 7, height: 7, decoration: const BoxDecoration(color: Colors.greenAccent, shape: BoxShape.circle)),
                const SizedBox(width: 5),
                const Text('Online', style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dayDivider(String label) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: BoxDecoration(color: AppColors.edgeSoft, borderRadius: BorderRadius.circular(20)),
        child: Text(label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.inkMuted)),
      ),
    );
  }

  // ── Bubbles ──────────────────────────────────────────────────────────────
  Widget _botAvatar() {
    return Container(
      width: 28, height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: AppColors.primaryMuted, shape: BoxShape.circle),
      child: Icon(Icons.smart_toy_rounded, size: 16, color: AppColors.primaryHover),
    );
  }

  Widget _botBubble(_ChatMessage m) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _botAvatar(),
        const SizedBox(width: 9),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(6),
                    topRight: Radius.circular(18),
                    bottomLeft: Radius.circular(18),
                    bottomRight: Radius.circular(18),
                  ),
                  border: Border.all(color: AppColors.edge),
                  boxShadow: [BoxShadow(color: AppColors.primaryDeep.withValues(alpha: 0.05), blurRadius: 14, offset: const Offset(0, 5))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(m.text, style: TextStyle(fontSize: 14, height: 1.45, color: AppColors.ink, fontWeight: FontWeight.w500)),
                    // Action buttons from AI response
                    if (m.hasRescue) ...[
                      const SizedBox(height: 10),
                      InkWell(
                        onTap: () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (_) => const RescueBottomSheet(),
                          );
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.dangerBg,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.warning_rounded, size: 16, color: AppColors.danger),
                              const SizedBox(width: 6),
                              Text('Call Rescue Now', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.danger)),
                            ],
                          ),
                        ),
                      ),
                    ],
                    if (m.hasBooking) ...[
                      const SizedBox(height: 10),
                      InkWell(
                        onTap: () => Navigator.of(context).popUntil((route) => route.isFirst),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.calendar_month_rounded, size: 16, color: AppColors.primaryDeep),
                              const SizedBox(width: 6),
                              Text('Book Appointment', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primaryDeep)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (m.time.isNotEmpty) ...[
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Text(m.time, style: TextStyle(fontSize: 11, color: AppColors.faint)),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 40),
      ],
    );
  }

  Widget _userBubble(_ChatMessage m) {
    return Row(
      children: [
        const SizedBox(width: 40),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                decoration: BoxDecoration(
                  gradient: AppStyles.brandGradient,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(18),
                    topRight: Radius.circular(6),
                    bottomLeft: Radius.circular(18),
                    bottomRight: Radius.circular(18),
                  ),
                  boxShadow: [BoxShadow(color: AppColors.primaryHover.withValues(alpha: 0.4), blurRadius: 16, offset: const Offset(0, 7))],
                ),
                child: Text(m.text, style: const TextStyle(fontSize: 14, height: 1.35, color: Colors.white, fontWeight: FontWeight.w500)),
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(m.time, style: TextStyle(fontSize: 11, color: AppColors.faint)),
                    const SizedBox(width: 3),
                    Icon(Icons.done_all_rounded, size: 14, color: AppColors.primary),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _typingBubble() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _botAvatar(),
        const SizedBox(width: 9),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.edge),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _AnimatedDot(delay: 0),
              const SizedBox(width: 4),
              _AnimatedDot(delay: 150),
              const SizedBox(width: 4),
              _AnimatedDot(delay: 300),
              const SizedBox(width: 8),
              Text('AI is thinking...', style: TextStyle(fontSize: 12, color: AppColors.faint, fontStyle: FontStyle.italic)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _suggestionsRow() {
    return Padding(
      padding: const EdgeInsets.only(left: 37),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _suggestions.map((q) => InkWell(
          onTap: () => _send(q),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.primary, width: 1.4),
            ),
            child: Text(q, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primaryDeep)),
          ),
        )).toList(),
      ),
    );
  }

  // ── Input bar ──────────────────────────────────────────────────────────────
  Widget _inputBar() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.edge)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.only(left: 16, right: 8),
                decoration: BoxDecoration(
                  color: AppColors.fieldFill,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.edge),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _input,
                        minLines: 1,
                        maxLines: 4,
                        textInputAction: TextInputAction.send,
                        onSubmitted: _send,
                        style: TextStyle(fontSize: 14, color: AppColors.ink, fontWeight: FontWeight.w500),
                        decoration: InputDecoration(
                          isCollapsed: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                          border: InputBorder.none,
                          hintText: 'Ask about your bike…',
                          hintStyle: TextStyle(fontSize: 14, color: AppColors.faint, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            InkWell(
              onTap: _botTyping ? null : () => _send(_input.text),
              borderRadius: BorderRadius.circular(24),
              child: Container(
                width: 48, height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: _botTyping ? null : AppStyles.brandGradient,
                  color: _botTyping ? AppColors.faint : null,
                  shape: BoxShape.circle,
                  boxShadow: _botTyping ? null : [BoxShadow(color: AppColors.primaryHover.withValues(alpha: 0.45), blurRadius: 14, offset: const Offset(0, 6))],
                ),
                child: const Icon(Icons.send_rounded, color: Colors.white, size: 22),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Animated bouncing dot for the typing indicator.
class _AnimatedDot extends StatefulWidget {
  final int delay;
  const _AnimatedDot({required this.delay});

  @override
  State<_AnimatedDot> createState() => _AnimatedDotState();
}

class _AnimatedDotState extends State<_AnimatedDot> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _anim = Tween<double>(begin: 0, end: -6).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _ctrl.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Transform.translate(
        offset: Offset(0, _anim.value),
        child: Container(
          width: 7, height: 7,
          decoration: BoxDecoration(color: AppColors.faint, shape: BoxShape.circle),
        ),
      ),
    );
  }
}
