import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme.dart';

/// Help Center chat — UI/layout only (no backend yet). Replies are canned and
/// local so the screen feels alive without a server.
class SupportChatScreen extends StatefulWidget {
  const SupportChatScreen({super.key});

  @override
  State<SupportChatScreen> createState() => _SupportChatScreenState();
}

class _ChatMessage {
  final String text;
  final bool fromUser;
  final String time;
  const _ChatMessage(this.text, this.fromUser, this.time);
}

class _SupportChatScreenState extends State<SupportChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();

  final List<_ChatMessage> _messages = [
    const _ChatMessage('Hi Minh 👋 Welcome to CareBike Support. How can we help you today?', false, '09:24'),
    const _ChatMessage("My bike's overdue for an oil change. Can I book today?", true, '09:25'),
    const _ChatMessage('Absolutely! District 1 has a 09:30 slot open. Want me to reserve it? 🛵', false, '09:25'),
  ];

  bool _botTyping = true;
  bool _showQuickReplies = true;

  static const _quickReplies = ['Yes, book it', 'Pick another time', 'Talk to a human'];

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

  void _send(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    setState(() {
      _messages.add(_ChatMessage(trimmed, true, _now()));
      _input.clear();
      _showQuickReplies = false;
      _botTyping = true;
    });
    _scrollToEnd();
    // Local canned reply — placeholder until the backend is wired up.
    Future.delayed(const Duration(milliseconds: 1100), () {
      if (!mounted) return;
      setState(() {
        _botTyping = false;
        _messages.add(_ChatMessage('Thanks! A CareBike teammate will follow up shortly. 🙌', false, _now()));
      });
      _scrollToEnd();
    });
  }

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
                if (_showQuickReplies) _quickReplyRow(),
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
            child: const Icon(Icons.support_agent_rounded, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 12),
          Text('CareBike Support', style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white)),
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
      child: Icon(Icons.support_agent_rounded, size: 16, color: AppColors.primaryHover),
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
                child: Text(m.text, style: TextStyle(fontSize: 14, height: 1.35, color: AppColors.ink, fontWeight: FontWeight.w500)),
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Text(m.time, style: TextStyle(fontSize: 11, color: AppColors.faint)),
              ),
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.edge),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (i) => Padding(
              padding: EdgeInsets.only(right: i == 2 ? 0 : 5),
              child: Container(
                width: 7, height: 7,
                decoration: BoxDecoration(color: AppColors.faint, shape: BoxShape.circle),
              ),
            )),
          ),
        ),
      ],
    );
  }

  Widget _quickReplyRow() {
    return Padding(
      padding: const EdgeInsets.only(left: 37),
      child: Align(
        alignment: Alignment.centerRight,
        child: Wrap(
          alignment: WrapAlignment.end,
          spacing: 9,
          runSpacing: 9,
          children: _quickReplies.map((q) => InkWell(
            onTap: () => _send(q),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.primary, width: 1.4),
              ),
              child: Text(q, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primaryDeep)),
            ),
          )).toList(),
        ),
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
                          hintText: 'Message…',
                          hintStyle: TextStyle(fontSize: 14, color: AppColors.faint, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ),
                    Icon(Icons.emoji_emotions_outlined, color: AppColors.faint, size: 22),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            InkWell(
              onTap: () => _send(_input.text),
              borderRadius: BorderRadius.circular(24),
              child: Container(
                width: 48, height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: AppStyles.brandGradient,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: AppColors.primaryHover.withValues(alpha: 0.45), blurRadius: 14, offset: const Offset(0, 6))],
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
