import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'package:mobile_app/core/network/api_client.dart';
import 'package:mobile_app/core/theme/theme.dart';
import 'package:mobile_app/features/auth/providers/auth_provider.dart';
import 'package:mobile_app/features/inspection/screens/inspection_flow.dart';
import 'package:mobile_app/features/maintenance/screens/history_tab.dart';
import 'package:mobile_app/features/rescue/widgets/rescue_bottom_sheet.dart';
import 'package:mobile_app/features/vehicle/models/vehicle.dart';

class ChatBookingRequest {
  final int? vehicleId;
  final String note;

  const ChatBookingRequest({
    this.vehicleId,
    required this.note,
  });
}

class SupportChatScreen extends StatefulWidget {
  const SupportChatScreen({super.key});

  @override
  State<SupportChatScreen> createState() => _SupportChatScreenState();
}

class _AiAction {
  final String type;
  final String label;
  final String? payload;

  const _AiAction({
    required this.type,
    required this.label,
    this.payload,
  });

  factory _AiAction.fromJson(Map<String, dynamic> json) => _AiAction(
        type: json['type']?.toString() ?? '',
        label: json['label']?.toString() ?? '',
        payload: json['payload']?.toString(),
      );
}

class _HealthCard {
  final String label;
  final String status;
  final String detail;
  final String tone;

  const _HealthCard({
    required this.label,
    required this.status,
    required this.detail,
    required this.tone,
  });

  factory _HealthCard.fromJson(Map<String, dynamic> json) => _HealthCard(
        label: json['label']?.toString() ?? '',
        status: json['status']?.toString() ?? '',
        detail: json['detail']?.toString() ?? '',
        tone: json['tone']?.toString() ?? 'warning',
      );
}

class _ChatMessage {
  final String text;
  final bool fromUser;
  final String time;
  final String? vehicleLabel;
  final String? urgency;
  final List<_HealthCard> healthCards;
  final List<_AiAction> actions;

  const _ChatMessage({
    required this.text,
    required this.fromUser,
    required this.time,
    this.vehicleLabel,
    this.urgency,
    this.healthCards = const [],
    this.actions = const [],
  });
}

class _SupportChatScreenState extends State<SupportChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();

  final List<_ChatMessage> _messages = [];
  final List<Vehicle> _vehicles = [];
  Vehicle? _selectedVehicle;
  bool _botTyping = false;
  bool _loadingVehicles = true;
  String? _vehicleError;
  String? _pendingQuestion;

  static const _suggestions = [
    'When should I change my oil?',
    'My brake feels soft',
    'Scan tire wear',
    'Book a checkup',
  ];

  @override
  void initState() {
    super.initState();
    _messages.add(const _ChatMessage(
      text:
          'Hi, I am the CareBike AI Assistant - your smart motorcycle care advisor.\n\nChoose a vehicle and ask about maintenance, symptoms, or booking.',
      fromUser: false,
      time: '',
    ));
    _loadVehicles();
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _loadVehicles() async {
    setState(() {
      _loadingVehicles = true;
      _vehicleError = null;
    });

    try {
      final auth = context.read<AuthProvider>();
      final customerId = _currentCustomerId(auth.mysqlUser);
      if (customerId == null) {
        throw Exception('Login info not found.');
      }

      final response = await ApiClient.get('/vehicles/owner/$customerId');
      final data = ApiClient.parseResponse(response);
      final loaded = data is List
          ? data
              .map((item) => Vehicle.fromJson(Map<String, dynamic>.from(item)))
              .toList()
          : <Vehicle>[];

      if (!mounted) return;
      setState(() {
        _vehicles
          ..clear()
          ..addAll(loaded);
        _selectedVehicle = loaded.length == 1 ? loaded.first : null;
        _loadingVehicles = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _vehicles.clear();
        _selectedVehicle = null;
        _loadingVehicles = false;
        _vehicleError = e.statusCode == 404 ? null : e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _vehicles.clear();
        _selectedVehicle = null;
        _loadingVehicles = false;
        _vehicleError = 'Could not load your vehicles.';
      });
    }
  }

  int? _currentCustomerId(Map<String, dynamic>? user) {
    final value = user?['userId'] ?? user?['id'] ?? user?['user']?['id'];
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent + 140,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  String _now() {
    final t = TimeOfDay.now();
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _send(String text, {bool echoUser = true}) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _botTyping) return;

    if (echoUser) {
      _pendingQuestion = trimmed;
    }

    setState(() {
      if (echoUser) {
        _messages.add(_ChatMessage(text: trimmed, fromUser: true, time: _now()));
        _input.clear();
      }
      _botTyping = true;
    });
    _scrollToEnd();

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final customerId = _currentCustomerId(auth.mysqlUser);
    if (customerId == null) {
      _addBotMessage('Unable to identify your account. Please log in again.');
      return;
    }

    try {
      final payload = <String, dynamic>{
        'customerId': customerId,
        'message': trimmed,
        if (_selectedVehicle?.id != null) 'vehicleId': _selectedVehicle!.id,
      };
      final response = await ApiClient.post('/ai/consult', payload);
      final parsed = ApiClient.parseResponse(response);
      final data = Map<String, dynamic>.from(parsed as Map);
      final message = _messageFromResponse(data);

      final responseVehicleId = _asInt(data['vehicleId']);
      if (responseVehicleId != null) {
        final vehicle = _findVehicle(responseVehicleId);
        if (vehicle != null) {
          _selectedVehicle = vehicle;
        }
      }

      if (data['intent']?.toString() != 'VEHICLE_SELECTION') {
        _pendingQuestion = null;
      }

      if (!mounted) return;
      setState(() {
        _botTyping = false;
        _messages.add(message);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _botTyping = false;
        _messages.add(_ChatMessage(
          text: 'Sorry, I cannot connect to the AI service right now. Please try again later.',
          fromUser: false,
          time: _now(),
        ));
      });
    }
    _scrollToEnd();
  }

  _ChatMessage _messageFromResponse(Map<String, dynamic> data) {
    var reply = data['reply']?.toString() ?? 'Sorry, no response received.';
    final actions = _parseActions(data['actions']);

    final mergedActions = [...actions];
    if (reply.contains('[ACTION:RESCUE]')) {
      reply = reply.replaceAll('[ACTION:RESCUE]', '').trim();
      mergedActions.add(const _AiAction(type: 'RESCUE', label: 'Call rescue'));
    }
    if (reply.contains('[ACTION:BOOKING]')) {
      reply = reply.replaceAll('[ACTION:BOOKING]', '').trim();
      mergedActions.add(const _AiAction(type: 'BOOKING', label: 'Book a checkup'));
    }

    return _ChatMessage(
      text: reply,
      fromUser: false,
      time: _now(),
      vehicleLabel: data['vehicleLabel']?.toString(),
      urgency: data['urgency']?.toString(),
      healthCards: _parseHealthCards(data['healthCards']),
      actions: mergedActions,
    );
  }

  List<_AiAction> _parseActions(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((item) => _AiAction.fromJson(Map<String, dynamic>.from(item)))
        .where((action) => action.type.isNotEmpty && action.label.isNotEmpty)
        .toList();
  }

  List<_HealthCard> _parseHealthCards(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((item) => _HealthCard.fromJson(Map<String, dynamic>.from(item)))
        .where((card) => card.label.isNotEmpty)
        .toList();
  }

  void _addBotMessage(String text) {
    if (!mounted) return;
    setState(() {
      _botTyping = false;
      _messages.add(_ChatMessage(text: text, fromUser: false, time: _now()));
    });
    _scrollToEnd();
  }

  Vehicle? _findVehicle(int id) {
    for (final vehicle in _vehicles) {
      if (vehicle.id == id) return vehicle;
    }
    return null;
  }

  Future<void> _handleAction(_AiAction action) async {
    switch (action.type) {
      case 'SELECT_VEHICLE':
        final vehicleId = _asInt(action.payload);
        final vehicle = vehicleId == null ? null : _findVehicle(vehicleId);
        if (vehicle == null) return;
        setState(() => _selectedVehicle = vehicle);
        final pending = _pendingQuestion;
        if (pending != null && pending.trim().isNotEmpty) {
          await _send(pending, echoUser: false);
        }
        break;
      case 'AI_TIRE_SCAN':
        await openInspectionSheet(context);
        break;
      case 'RESCUE':
        if (!mounted) return;
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => const RescueBottomSheet(),
        );
        break;
      case 'BOOKING':
        if (!mounted) return;
        Navigator.pop(
          context,
          ChatBookingRequest(
            vehicleId: _asInt(action.payload),
            note: action.label,
          ),
        );
        break;
      case 'VIEW_HISTORY':
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const HistoryTab()),
        );
        break;
      case 'ADD_VEHICLE':
        _showHint('Open My Vehicles from the bottom navigation to add your bike.');
        break;
      default:
        _showHint(action.label);
    }
  }

  void _showHint(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.ink,
      ),
    );
  }

  Future<void> _openVehiclePicker() async {
    if (_vehicles.isEmpty) return;
    final selected = await showModalBottomSheet<Vehicle>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.edge,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Choose vehicle context',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 10),
                for (final vehicle in _vehicles)
                  _vehiclePickerItem(context, vehicle),
              ],
            ),
          ),
        );
      },
    );

    if (selected != null && mounted) {
      setState(() => _selectedVehicle = selected);
    }
  }

  Widget _vehiclePickerItem(BuildContext context, Vehicle vehicle) {
    final selected = _selectedVehicle?.id == vehicle.id;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.pop(context, vehicle),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected ? AppColors.primaryLight : AppColors.fieldFill,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.edge,
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.two_wheeler_rounded, color: AppColors.primaryHover),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _vehicleLabel(vehicle),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _vehicleMeta(vehicle),
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.inkMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                Icon(Icons.check_circle_rounded, color: AppColors.success),
            ],
          ),
        ),
      ),
    );
  }

  String _vehicleLabel(Vehicle vehicle) {
    final plate = vehicle.licensePlate.trim();
    final base = '${vehicle.brand} ${vehicle.vehicleName}'.trim();
    return plate.isEmpty ? base : '$base - $plate';
  }

  String _vehicleMeta(Vehicle vehicle) {
    final engine = vehicle.engineCapacity == null ? 'Engine N/A' : '${vehicle.engineCapacity} cc';
    final km = vehicle.currentKm == null ? 'Odometer N/A' : '${_fmt(vehicle.currentKm!)} km';
    return '${vehicle.typeLabel} - $engine - $km';
  }

  String _fmt(int value) {
    return value
        .toString()
        .replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (match) => '${match[1]},');
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
                _vehicleContextCard(),
                const SizedBox(height: 14),
                for (final message in _messages) ...[
                  message.fromUser ? _userBubble(message) : _botBubble(message),
                  const SizedBox(height: 14),
                ],
                if (_botTyping) ...[
                  _typingBubble(),
                  const SizedBox(height: 14),
                ],
                if (_messages.length == 1 && !_botTyping) _suggestionsRow(),
              ],
            ),
          ),
          _inputBar(),
        ],
      ),
    );
  }

  Widget _header() {
    final topInset = MediaQuery.of(context).padding.top;
    return Container(
      padding: EdgeInsets.fromLTRB(12, topInset + 8, 16, 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFFB923C), Color(0xFFF97316), Color(0xFFEA580C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
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
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.22),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CareBike AI',
                  style: GoogleFonts.poppins(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Maintenance Copilot',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.82),
                  ),
                ),
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
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: Colors.greenAccent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                const Text(
                  'Online',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
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
        decoration: BoxDecoration(
          color: AppColors.edgeSoft,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: AppColors.inkMuted,
          ),
        ),
      ),
    );
  }

  Widget _vehicleContextCard() {
    IconData icon = Icons.two_wheeler_rounded;
    String title = 'Vehicle context';
    String subtitle = 'Choose a bike so AI can personalize advice.';
    VoidCallback? onTap = _vehicles.isEmpty ? null : _openVehiclePicker;

    if (_loadingVehicles) {
      icon = Icons.sync_rounded;
      subtitle = 'Loading your saved vehicles...';
    } else if (_vehicleError != null) {
      icon = Icons.cloud_off_rounded;
      title = 'Vehicle profile unavailable';
      subtitle = _vehicleError!;
      onTap = _loadVehicles;
    } else if (_vehicles.isEmpty) {
      icon = Icons.add_road_rounded;
      title = 'No vehicle saved';
      subtitle = 'Add a vehicle in My Vehicles to unlock personal advice.';
      onTap = () => _handleAction(const _AiAction(type: 'ADD_VEHICLE', label: 'Add vehicle'));
    } else if (_selectedVehicle != null) {
      title = _vehicleLabel(_selectedVehicle!);
      subtitle = _vehicleMeta(_selectedVehicle!);
    } else {
      icon = Icons.tune_rounded;
      title = 'Choose vehicle';
      subtitle = '${_vehicles.length} saved bikes available';
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.edge),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryDeep.withValues(alpha: 0.04),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primaryMuted,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: AppColors.primaryHover, size: 21),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.inkMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            if (!_loadingVehicles && _vehicles.isNotEmpty)
              Icon(Icons.expand_more_rounded, color: AppColors.inkMuted),
          ],
        ),
      ),
    );
  }

  Widget _botAvatar() {
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.primaryMuted,
        shape: BoxShape.circle,
      ),
      child: Icon(Icons.smart_toy_rounded, size: 16, color: AppColors.primaryHover),
    );
  }

  Widget _botBubble(_ChatMessage message) {
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
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryDeep.withValues(alpha: 0.05),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (message.vehicleLabel != null && message.vehicleLabel!.isNotEmpty)
                      _vehicleChip(message.vehicleLabel!),
                    if (message.vehicleLabel != null && message.vehicleLabel!.isNotEmpty)
                      const SizedBox(height: 9),
                    Text(
                      message.text,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.45,
                        color: AppColors.ink,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (message.healthCards.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      for (final card in message.healthCards) ...[
                        _healthTile(card),
                        const SizedBox(height: 8),
                      ],
                    ],
                    if (message.actions.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: message.actions
                            .map((action) => _actionButton(action))
                            .toList(),
                      ),
                    ],
                  ],
                ),
              ),
              if (message.time.isNotEmpty) ...[
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Text(
                    message.time,
                    style: TextStyle(fontSize: 11, color: AppColors.faint),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 40),
      ],
    );
  }

  Widget _vehicleChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primaryMuted),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.two_wheeler_rounded, size: 14, color: AppColors.primaryDeep),
          const SizedBox(width: 5),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 210),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                color: AppColors.primaryDeep,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _healthTile(_HealthCard card) {
    final color = _toneColor(card.tone);
    final bg = _toneBg(card.tone);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(_healthIcon(card.label), size: 17, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        card.label,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                    Text(
                      card.status,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                    ),
                  ],
                ),
                if (card.detail.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    card.detail,
                    style: TextStyle(
                      fontSize: 11.5,
                      height: 1.3,
                      color: AppColors.inkMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _toneColor(String tone) {
    return switch (tone) {
      'success' => AppColors.success,
      'danger' => AppColors.danger,
      'info' => AppColors.info,
      _ => AppColors.warning,
    };
  }

  Color _toneBg(String tone) {
    return switch (tone) {
      'success' => AppColors.successBg,
      'danger' => AppColors.dangerBg,
      'info' => AppColors.primaryLight,
      _ => AppColors.warningBg,
    };
  }

  IconData _healthIcon(String label) {
    final lower = label.toLowerCase();
    if (lower.contains('oil')) return Icons.opacity_rounded;
    if (lower.contains('brake')) return Icons.album_rounded;
    if (lower.contains('tire')) return Icons.radio_button_checked_rounded;
    return Icons.health_and_safety_rounded;
  }

  Widget _actionButton(_AiAction action) {
    final danger = action.type == 'RESCUE';
    final filled = action.type == 'BOOKING' || action.type == 'AI_TIRE_SCAN';
    final color = danger ? AppColors.danger : AppColors.primaryHover;
    final textColor = filled ? Colors.white : color;

    return InkWell(
      onTap: () => _handleAction(action),
      borderRadius: BorderRadius.circular(13),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        decoration: BoxDecoration(
          gradient: filled && !danger ? AppStyles.brandGradient : null,
          color: danger
              ? AppColors.dangerBg
              : filled
                  ? null
                  : AppColors.surface,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: danger ? AppColors.danger.withValues(alpha: 0.3) : AppColors.primary.withValues(alpha: 0.35),
          ),
          boxShadow: filled && !danger
              ? [
                  BoxShadow(
                    color: AppColors.primaryHover.withValues(alpha: 0.22),
                    blurRadius: 12,
                    offset: const Offset(0, 5),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_actionIcon(action.type), size: 16, color: textColor),
            const SizedBox(width: 6),
            Text(
              action.label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _actionIcon(String type) {
    return switch (type) {
      'SELECT_VEHICLE' => Icons.two_wheeler_rounded,
      'AI_TIRE_SCAN' => Icons.photo_camera_rounded,
      'RESCUE' => Icons.warning_rounded,
      'BOOKING' => Icons.calendar_month_rounded,
      'VIEW_HISTORY' => Icons.receipt_long_rounded,
      'ADD_VEHICLE' => Icons.add_rounded,
      _ => Icons.arrow_forward_rounded,
    };
  }

  Widget _userBubble(_ChatMessage message) {
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
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryHover.withValues(alpha: 0.4),
                      blurRadius: 16,
                      offset: const Offset(0, 7),
                    ),
                  ],
                ),
                child: Text(
                  message.text,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.35,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      message.time,
                      style: TextStyle(fontSize: 11, color: AppColors.faint),
                    ),
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
              const _AnimatedDot(delay: 0),
              const SizedBox(width: 4),
              const _AnimatedDot(delay: 150),
              const SizedBox(width: 4),
              const _AnimatedDot(delay: 300),
              const SizedBox(width: 8),
              Text(
                'AI is thinking...',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.faint,
                  fontStyle: FontStyle.italic,
                ),
              ),
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
        children: _suggestions
            .map(
              (question) => InkWell(
                onTap: () => _send(question),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.primary, width: 1.4),
                  ),
                  child: Text(
                    question,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryDeep,
                    ),
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

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
                child: TextField(
                  controller: _input,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  onSubmitted: _send,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.ink,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    isCollapsed: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    border: InputBorder.none,
                    hintText: 'Ask about your bike...',
                    hintStyle: TextStyle(
                      fontSize: 14,
                      color: AppColors.faint,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            InkWell(
              onTap: _botTyping ? null : () => _send(_input.text),
              borderRadius: BorderRadius.circular(24),
              child: Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: _botTyping ? null : AppStyles.brandGradient,
                  color: _botTyping ? AppColors.faint : null,
                  shape: BoxShape.circle,
                  boxShadow: _botTyping
                      ? null
                      : [
                          BoxShadow(
                            color: AppColors.primaryHover.withValues(alpha: 0.45),
                            blurRadius: 14,
                            offset: const Offset(0, 6),
                          ),
                        ],
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

class _AnimatedDot extends StatefulWidget {
  final int delay;
  const _AnimatedDot({required this.delay});

  @override
  State<_AnimatedDot> createState() => _AnimatedDotState();
}

class _AnimatedDotState extends State<_AnimatedDot> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _anim = Tween<double>(begin: 0, end: -6).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
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
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: AppColors.faint,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}
