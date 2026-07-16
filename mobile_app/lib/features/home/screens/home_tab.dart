import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_app/core/network/api_client.dart';
import 'package:mobile_app/core/theme/theme.dart';
import 'package:mobile_app/core/theme/theme_controller.dart';
import 'package:mobile_app/features/catalog/models/category.dart';
import 'package:mobile_app/features/catalog/models/spare_part.dart';
import 'package:mobile_app/features/auth/providers/auth_provider.dart';
import 'package:mobile_app/features/branch/models/branch.dart';
import 'package:mobile_app/features/rescue/widgets/rescue_bottom_sheet.dart';
import 'package:mobile_app/features/appointment/screens/customer_appointment_screen.dart';
import 'package:mobile_app/features/branch/screens/branch_map_screen.dart';
import 'package:mobile_app/features/chat/screens/support_chat_screen.dart';
import 'package:mobile_app/features/catalog/screens/spare_parts_screen.dart';

// ── Carousel banners (presentational) ────────────────────────────────────────
class _Banner {
  final String tag, title, sub;
  final IconData icon;
  const _Banner(this.tag, this.title, this.sub, this.icon);
}

const _banners = <_Banner>[
  _Banner(
    'Limited offer',
    '20% off your first service',
    'New riders only · ends Sunday',
    Icons.redeem,
  ),
  _Banner(
    'Free pickup',
    'We collect your bike',
    'Doorstep pickup within 5 km',
    Icons.two_wheeler,
  ),
  _Banner(
    'Express',
    'Oil change in 20 minutes',
    'Walk in — no booking needed',
    Icons.bolt,
  ),
];

// ── Quick-action tabs (visual shortcuts) ─────────────────────────────────────
enum _QuickAction { branchMap, support, rescue, spareParts, bookings }

class _Quick {
  final String label;
  final IconData icon;
  final _QuickAction action;
  const _Quick(this.label, this.icon, this.action);
}

const _quick = <_Quick>[
  _Quick('Branches', Icons.pin_drop_rounded, _QuickAction.branchMap),
  _Quick('Rescue', Icons.emergency_rounded, _QuickAction.rescue),
  _Quick('Spare Parts', Icons.build_circle_outlined, _QuickAction.spareParts),
  _Quick('Support', Icons.support_agent_rounded, _QuickAction.support),
  _Quick('Bookings', Icons.calendar_today_rounded, _QuickAction.bookings),
];

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  static const int _openingHour = 8;
  static const int _closingHour = 20;
  static const String _workingHoursMessage =
      'Appointments are available from 8:00 AM to 8:00 PM.';
  List<Branch> _branches = [];
  bool _branchesLoading = true;

  List<SparePart> _spareParts = [];
  bool _sparePartsLoading = true;

  List<CategoryModel> _categories = [];
  bool _categoriesLoading = true;
  int? _selectedCategoryId;
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();

  Branch? _selectedBranch;
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  int? _selectedVehicleId;
  final _noteCtrl = TextEditingController();
  bool _isBooking = false;
  String? _bookingError;
  String? _bookingSuccess;

  List<Map<String, dynamic>> _vehicles = [];
  bool _vehiclesLoading = true;

  // Carousel state (purely presentational)
  final PageController _bannerCtrl = PageController();
  int _bannerIndex = 0;
  Timer? _bannerTimer;

  @override
  void initState() {
    super.initState();
    _loadBranches();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadVehicles();
    });

    _bannerTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || !_bannerCtrl.hasClients) return;
      _bannerCtrl.animateToPage(
        (_bannerIndex + 1) % _banners.length,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    _bannerCtrl.dispose();
    _bannerTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadVehicles() async {
    final userId = context.read<AuthProvider>().mysqlUser?['userId'];
    if (userId == null) {
      setState(() => _vehiclesLoading = false);
      return;
    }

    setState(() => _vehiclesLoading = true);
    try {
      final response = await ApiClient.get('/vehicles/owner/$userId');
      final data = ApiClient.parseResponse(response) as List;
      setState(() {
        _vehicles = List<Map<String, dynamic>>.from(data);
        if (_vehicles.isNotEmpty) {
          _selectedVehicleId = _vehicles.first['id'] as int;
        }
        _vehiclesLoading = false;
      });
    } catch (_) {
      setState(() => _vehiclesLoading = false);
    }
  }

  Future<void> _loadBranches() async {
    setState(() => _branchesLoading = true);
    try {
      final response = await ApiClient.get('/branches');
      final data = ApiClient.parseResponse(response) as List;
      setState(() {
        _branches = data
            .map((e) => Branch.fromJson(e as Map<String, dynamic>))
            .toList();
        _branchesLoading = false;
      });
    } catch (_) {
      setState(() => _branchesLoading = false);
    }
  }

  Future<void> _pickDate() async {
    // Free scrollable date wheel — matches the time picker.
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final maxDate = today.add(const Duration(days: 90));
    DateTime temp = _selectedDate ?? today.add(const Duration(days: 1));
    if (temp.isBefore(today)) temp = today;
    if (temp.isAfter(maxDate)) temp = maxDate;

    final picked = await showModalBottomSheet<DateTime>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
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
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.calendar_today_rounded,
                    size: 17,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Choose appointment date',
                  style: AppStyles.section(size: 16),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 190,
              child: CupertinoTheme(
                data: CupertinoThemeData(
                  textTheme: CupertinoTextThemeData(
                    dateTimePickerTextStyle: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                ),
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.date,
                  initialDateTime: temp,
                  minimumDate: today,
                  maximumDate: maxDate,
                  onDateTimeChanged: (dt) => temp = dt,
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                onPressed: () => Navigator.pop(
                  ctx,
                  DateTime(temp.year, temp.month, temp.day),
                ),
                child: const Text('Confirm'),
              ),
            ),
          ],
        ),
      ),
    );

    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime() async {
    // Free scrollable time wheel (any hour:minute) — clean, no analog clock.
    final now = _selectedTime ?? const TimeOfDay(hour: 9, minute: 0);
    DateTime temp = DateTime(2024, 1, 1, now.hour, now.minute);

    final picked = await showModalBottomSheet<TimeOfDay>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
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
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.access_time_rounded,
                    size: 18,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Choose appointment time',
                  style: AppStyles.section(size: 16),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 190,
              child: CupertinoTheme(
                data: CupertinoThemeData(
                  textTheme: CupertinoTextThemeData(
                    dateTimePickerTextStyle: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                ),
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.time,
                  use24hFormat: true,
                  minuteInterval: 1,
                  initialDateTime: temp,
                  onDateTimeChanged: (dt) => temp = dt,
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                onPressed: () => Navigator.pop(
                  ctx,
                  TimeOfDay(hour: temp.hour, minute: temp.minute),
                ),
                child: const Text('Confirm'),
              ),
            ),
          ],
        ),
      ),
    );

    if (picked == null) return;
    if (!_isWithinWorkingHours(picked)) {
      setState(() => _selectedTime = null);
      await _showOutsideWorkingHoursDialog();
      return;
    }
    setState(() => _selectedTime = picked);
  }

  bool _isWithinWorkingHours(TimeOfDay time) {
    final minutes = time.hour * 60 + time.minute;
    return minutes >= _openingHour * 60 && minutes <= _closingHour * 60;
  }

  Future<void> _showOutsideWorkingHoursDialog() async {
    final openRescue = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: Icon(Icons.emergency_rounded, color: AppColors.danger, size: 34),
        title: const Text('Outside working hours'),
        content: const Text(
          'Appointments are available from 8:00 AM to 8:00 PM. '
          'If your motorcycle needs urgent assistance, our 24/7 Rescue service can help.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Choose another time'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.sos_rounded),
            label: const Text('Open Rescue'),
          ),
        ],
      ),
    );

    if (openRescue == true && mounted) {
      RescueBottomSheet.show(context);
    }
  }

  Future<void> _submitBooking() async {
    if (_selectedBranch == null) {
      setState(() => _bookingError = 'Please select a branch.');
      return;
    }
    if (_selectedVehicleId == null) {
      setState(() => _bookingError = 'Please select your vehicle.');
      return;
    }
    if (_selectedDate == null || _selectedTime == null) {
      setState(() => _bookingError = 'Please select a date and time.');
      return;
    }
    if (!_isWithinWorkingHours(_selectedTime!)) {
      setState(() => _bookingError = _workingHoursMessage);
      await _showOutsideWorkingHoursDialog();
      return;
    }

    setState(() {
      _isBooking = true;
      _bookingError = null;
      _bookingSuccess = null;
    });

    final userId = context.read<AuthProvider>().mysqlUser?['userId'];
    final dt = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _selectedTime!.hour,
      _selectedTime!.minute,
    );

    try {
      final response = await ApiClient.post('/appointments', {
        'customerId': userId,
        'branchId': _selectedBranch!.id,
        'vehicleId': _selectedVehicleId,
        'appointmentDate': dt.toIso8601String(),
        'note': _noteCtrl.text.trim(),
      });
      final data = ApiClient.parseResponse(response);
      bool allStaffBusy = false;
      if (data != null && data['allStaffBusy'] == true) {
        allStaffBusy = true;
      }
      setState(() {
        _bookingSuccess = allStaffBusy
            ? 'Tất cả nhân viên đang bận, vui lòng chờ. Đơn của bạn đã được lưu tại chi nhánh.'
            : 'Booked successfully! The branch will confirm soon.';
        _isBooking = false;
        _selectedBranch = null;
        _selectedDate = null;
        _selectedTime = null;
        _noteCtrl.clear();
      });
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          // Check the user is still on this screen
          setState(() {
            _bookingSuccess = null;
          });
        }
      });
    } on ApiException catch (e) {
      setState(() {
        _bookingError = e.message;
        _isBooking = false;
      });
    } catch (_) {
      setState(() {
        _bookingError = 'Something went wrong. Please try again.';
        _isBooking = false;
      });
    }
  }

  String _dateLabel() => _selectedDate == null
      ? 'Pick date'
      : '${_selectedDate!.day.toString().padLeft(2, '0')}/${_selectedDate!.month.toString().padLeft(2, '0')}/${_selectedDate!.year}';

  String _timeLabel() => _selectedTime == null
      ? 'Pick time'
      : '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final name =
        (auth.mysqlUser?['fullName'] ?? auth.firebaseUser?.email ?? 'Guest')
            .toString();
    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : 'C';

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          await Future.wait([_loadBranches(), _loadVehicles()]);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          children: [
            _header(),
            _greeting(name, initial),
            const SizedBox(height: 16),
            _carousel(),
            const SizedBox(height: 4),
            _quickTabs(),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 28),
              child: _bookingCard(),
            ),
          ],
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────
  Widget _header() {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _iconButton(
              icon: ThemeController.instance.isDark
                  ? Icons.light_mode_rounded
                  : Icons.dark_mode_rounded,
              color: AppColors.primary,
              onTap: () => ThemeController.instance.toggle(),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'CARE',
                  style: GoogleFonts.montserrat(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    fontStyle: FontStyle.italic,
                    color: AppColors.primary,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  'BIKE',
                  style: GoogleFonts.montserrat(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    fontStyle: FontStyle.italic,
                    color: AppColors.ink,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
            Stack(
              clipBehavior: Clip.none,
              children: [
                _iconButton(
                  icon: Icons.notifications_rounded,
                  color: AppColors.ink,
                  onTap: () {},
                ),
                Positioned(
                  top: 9,
                  right: 10,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.canvas, width: 2),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _iconButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(13),
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: AppColors.edge),
        ),
        child: Icon(icon, size: 22, color: color),
      ),
    );
  }

  // ── Greeting ───────────────────────────────────────────────────────────────
  Widget _greeting(String name, String initial) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 5),
                Text(
                  'Hello, $name',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 25,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: AppColors.ink,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [AppColors.primaryBright, AppColors.primaryHover],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryHover.withValues(alpha: 0.45),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Text(
              initial,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Carousel ───────────────────────────────────────────────────────────────
  Widget _carousel() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: SizedBox(
          height: 152,
          child: Stack(
            children: [
              PageView.builder(
                controller: _bannerCtrl,
                onPageChanged: (i) => setState(() => _bannerIndex = i),
                itemCount: _banners.length,
                itemBuilder: (_, i) => _bannerSlide(_banners[i]),
              ),
              Positioned(
                bottom: 13,
                left: 24,
                child: Row(
                  children: List.generate(_banners.length, (i) {
                    final active = i == _bannerIndex;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.only(right: 6),
                      width: active ? 20 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: active
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bannerSlide(_Banner b) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFFB923C), Color(0xFFF97316), Color(0xFFEA580C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -34,
            top: -34,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.13),
              ),
            ),
          ),
          Positioned(
            right: 6,
            bottom: -22,
            child: Icon(
              b.icon,
              size: 108,
              color: Colors.white.withValues(alpha: 0.18),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    b.tag.toUpperCase(),
                    style: GoogleFonts.orbitron(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.5,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 215),
                  child: Text(
                    b.title,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                      height: 1.12,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  b.sub,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Quick tabs ─────────────────────────────────────────────────────────────
  /// Route a quick-tab tap to its destination (mirrors the side-drawer actions).
  void _onQuickTap(_QuickAction action) {
    switch (action) {
      case _QuickAction.branchMap:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const BranchMapScreen()),
        );
      case _QuickAction.support:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SupportChatScreen()),
        );
      case _QuickAction.spareParts:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SparePartsScreen()),
        );
      case _QuickAction.rescue:
        RescueBottomSheet.show(context);
      case _QuickAction.bookings:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CustomerAppointmentScreen()),
        );
    }
  }

  Widget _quickTabs() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 26, 16, 0),
      child: Row(
        children: _quick.map((q) {
          return Expanded(
            child: InkWell(
              onTap: () => _onQuickTap(q.action),
              borderRadius: BorderRadius.circular(18),
              child: Column(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.primaryMuted),
                    ),
                    child: Icon(
                      q.icon,
                      size: 25,
                      color: AppColors.primaryHover,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    q.label,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.inkMuted,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Booking card ───────────────────────────────────────────────────────────
  Widget _bookingCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.edge),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDeep.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primaryMuted,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  Icons.event_available_rounded,
                  size: 21,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Book maintenance',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                        letterSpacing: -0.2,
                      ),
                    ),
                    Text(
                      'Reserve a slot in under a minute',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: AppColors.inkMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Branch selector
          if (_branchesLoading)
            _fieldShell(
              child: Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary,
                    ),
                  ),
                  SizedBox(width: 10),
                  Text(
                    'Loading branches…',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.inkMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            )
          else
            _fieldShell(
              child: Row(
                children: [
                  Icon(Icons.store_rounded, size: 19, color: AppColors.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<Branch>(
                        value: _selectedBranch,
                        isExpanded: true,
                        isDense: true,
                        hint: Text(
                          'Select branch',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.inkMuted,
                          ),
                        ),
                        icon: Icon(
                          Icons.expand_more_rounded,
                          color: AppColors.inkMuted,
                        ),
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.ink,
                        ),
                        items: _branches
                            .map(
                              (b) => DropdownMenuItem(
                                value: b,
                                child: Text(
                                  b.name,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => setState(() => _selectedBranch = v),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 11),

          // Vehicle selector
          if (_vehiclesLoading)
            _fieldShell(
              child: Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary,
                    ),
                  ),
                  SizedBox(width: 10),
                  Text(
                    'Loading vehicles…',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.inkMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            )
          else if (_vehicles.isEmpty)
            _fieldShell(
              child: Row(
                children: [
                  Icon(
                    Icons.directions_bike_rounded,
                    size: 19,
                    color: AppColors.danger,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'No vehicles found. Please add a vehicle first.',
                    style: TextStyle(fontSize: 13, color: AppColors.danger),
                  ),
                ],
              ),
            )
          else
            _fieldShell(
              child: Row(
                children: [
                  Icon(
                    Icons.directions_bike_rounded,
                    size: 19,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: _selectedVehicleId,
                        isExpanded: true,
                        isDense: true,
                        hint: Text(
                          'Select your vehicle',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.inkMuted,
                          ),
                        ),
                        icon: Icon(
                          Icons.expand_more_rounded,
                          color: AppColors.inkMuted,
                        ),
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.ink,
                        ),
                        items: _vehicles
                            .map(
                              (v) => DropdownMenuItem<int>(
                                value: v['id'] as int,
                                child: Text(
                                  '${v['vehicleName']} - ${v['licensePlate'] ?? 'N/A'}',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _selectedVehicleId = v),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 11),

          // Date + time
          Row(
            children: [
              Expanded(
                child: _pickerTile(
                  Icons.calendar_today_rounded,
                  _dateLabel(),
                  _selectedDate != null,
                  _pickDate,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: _pickerTile(
                  Icons.schedule_rounded,
                  _timeLabel(),
                  _selectedTime != null,
                  _pickTime,
                ),
              ),
            ],
          ),
          const SizedBox(height: 11),

          // Note
          _fieldShell(
            child: TextField(
              controller: _noteCtrl,
              maxLines: 1,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.ink,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: 'Note (e.g. oil change, brake check…)',
                hintStyle: TextStyle(
                  fontSize: 13,
                  color: AppColors.inkMuted,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),

          if (_bookingError != null) ...[
            const SizedBox(height: 11),
            _banner(_bookingError!, isError: true),
          ],
          if (_bookingSuccess != null) ...[
            const SizedBox(height: 11),
            _banner(_bookingSuccess!, isError: false),
          ],

          const SizedBox(height: 16),

          // Book now
          GestureDetector(
            onTap: _isBooking ? null : _submitBooking,
            child: Container(
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFFFB923C),
                    Color(0xFFF97316),
                    Color(0xFFEA580C),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.55),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: _isBooking
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Colors.white,
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.bolt_rounded, size: 20, color: Colors.white),
                        SizedBox(width: 8),
                        Text(
                          'Book now',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fieldShell({required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: AppColors.fieldFill,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.edge),
      ),
      child: child,
    );
  }

  Widget _pickerTile(
    IconData icon,
    String label,
    bool active,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: AppColors.fieldFill,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.edge),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.primary),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: active ? AppColors.ink : AppColors.inkMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _banner(String text, {required bool isError}) {
    final color = isError ? AppColors.danger : AppColors.success;
    final bg = isError ? AppColors.dangerBg : AppColors.successBg;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            isError
                ? Icons.error_outline_rounded
                : Icons.check_circle_outline_rounded,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
