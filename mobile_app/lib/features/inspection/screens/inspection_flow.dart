import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import 'package:mobile_app/core/network/api_client.dart';
import 'package:mobile_app/core/theme/theme.dart';
import 'package:mobile_app/features/auth/providers/auth_provider.dart';
import 'package:mobile_app/features/inspection/models/damage_models.dart';
import 'package:mobile_app/features/inspection/models/tire_quote_models.dart';
import 'package:mobile_app/features/inspection/screens/inspection_result_screen.dart';
import 'package:mobile_app/features/inspection/services/tire_recommendation_service.dart';
import 'package:mobile_app/features/inspection/services/vision_api_service.dart';
import 'package:mobile_app/features/vehicle/models/vehicle.dart';

const List<_GuidedCaptureStep> _guidedTireSteps = [
  _GuidedCaptureStep(
    title: 'Full tire view',
    instruction: 'Capture the whole wheel and tire so the AI has context.',
    icon: Icons.radio_button_checked_rounded,
  ),
  _GuidedCaptureStep(
    title: 'Center tread',
    instruction: 'Move closer and frame the middle tread area clearly.',
    icon: Icons.center_focus_strong_rounded,
  ),
  _GuidedCaptureStep(
    title: 'Left shoulder',
    instruction: 'Capture the left edge of the tread where uneven wear can hide.',
    icon: Icons.keyboard_arrow_left_rounded,
  ),
  _GuidedCaptureStep(
    title: 'Right shoulder',
    instruction: 'Capture the right edge of the tread from the same distance.',
    icon: Icons.keyboard_arrow_right_rounded,
  ),
  _GuidedCaptureStep(
    title: 'Sidewall',
    instruction: 'Capture the tire sidewall to check for cracks, cuts, or bulges.',
    icon: Icons.panorama_wide_angle_select_rounded,
  ),
];

/// Shared AI inspection entry point used by the Home tile and camera button.
Future<void> openInspectionSheet(BuildContext context, {VoidCallback? onOpenVehicles}) async {
  _showLoadingDialog(context, message: 'Loading your vehicles...');

  List<Vehicle> vehicles;
  try {
    vehicles = await _loadVehiclesForInspection(context);
  } catch (_) {
    if (context.mounted) Navigator.pop(context);
    if (context.mounted) {
      _showErrorDialog(context, 'Could not load your vehicles. Please try again.');
    }
    return;
  }

  if (!context.mounted) return;
  Navigator.pop(context);

  if (vehicles.isEmpty) {
    _showNoVehicleDialog(context, onOpenVehicles: onOpenVehicles);
    return;
  }

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (sheetContext) {
      Vehicle selectedVehicle = vehicles.first;
      TirePosition selectedPosition = TirePosition.rear;

      return StatefulBuilder(
        builder: (ctx, setSheetState) {
          final inspectionContext = _InspectionContext(
            vehicle: selectedVehicle,
            tirePosition: selectedPosition,
          );

          return SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sheetHandle(),
                    const SizedBox(height: 16),
                    _inspectionHeader(),
                    const SizedBox(height: 14),
                    _inspectionSetupCard(
                      vehicles: vehicles,
                      selectedVehicle: selectedVehicle,
                      selectedPosition: selectedPosition,
                      onVehicleChanged: (vehicle) {
                        if (vehicle == null) return;
                        setSheetState(() => selectedVehicle = vehicle);
                      },
                      onPositionChanged: (position) {
                        setSheetState(() => selectedPosition = position);
                      },
                    ),
                    const SizedBox(height: 12),
                    _quickScanCard(context, sheetContext, inspectionContext),
                    const SizedBox(height: 12),
                    _guidedFullCheckCard(context, sheetContext, inspectionContext),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

Widget _sheetHandle() {
  return Center(
    child: Container(
      width: 40,
      height: 4,
      decoration: BoxDecoration(color: AppColors.edge, borderRadius: BorderRadius.circular(2)),
    ),
  );
}

Widget _inspectionHeader() {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      gradient: AppStyles.brandGradient,
      borderRadius: BorderRadius.circular(18),
      boxShadow: AppStyles.glow,
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(13),
          ),
          child: const Icon(Icons.center_focus_strong_rounded, size: 23, color: Colors.white),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'AI tire inspection',
                style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white),
              ),
              const SizedBox(height: 4),
              Text(
                'Start with one photo or capture all required tire angles for stronger coverage.',
                style: TextStyle(
                  fontSize: 12.5,
                  color: Colors.white.withValues(alpha: 0.88),
                  height: 1.35,
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

Widget _inspectionSetupCard({
  required List<Vehicle> vehicles,
  required Vehicle selectedVehicle,
  required TirePosition selectedPosition,
  required ValueChanged<Vehicle?> onVehicleChanged,
  required ValueChanged<TirePosition> onPositionChanged,
}) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: AppColors.fieldFill,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppColors.edge),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: AppColors.primaryMuted, borderRadius: BorderRadius.circular(12)),
              child: Icon(Icons.motorcycle_rounded, size: 20, color: AppColors.primaryHover),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Inspection setup', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.ink)),
                  const SizedBox(height: 2),
                  Text(
                    'Choose the vehicle and tire position before scanning.',
                    style: TextStyle(fontSize: 12, color: AppColors.inkMuted, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 13),
        DropdownButtonFormField<Vehicle>(
          value: selectedVehicle,
          isExpanded: true,
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.surface,
            labelText: 'Vehicle',
            labelStyle: TextStyle(color: AppColors.inkMuted, fontWeight: FontWeight.w600),
            prefixIcon: Icon(Icons.two_wheeler_rounded, color: AppColors.primary),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: AppColors.edge),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: AppColors.edge),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: AppColors.primary, width: 1.4),
            ),
          ),
          items: vehicles
              .map(
                (vehicle) => DropdownMenuItem<Vehicle>(
                  value: vehicle,
                  child: Text(
                    _vehicleDisplayName(vehicle),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13.5, color: AppColors.ink, fontWeight: FontWeight.w700),
                  ),
                ),
              )
              .toList(growable: false),
          onChanged: onVehicleChanged,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _positionButton(
                label: 'Front tire',
                icon: Icons.arrow_upward_rounded,
                selected: selectedPosition == TirePosition.front,
                onTap: () => onPositionChanged(TirePosition.front),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _positionButton(
                label: 'Rear tire',
                icon: Icons.arrow_downward_rounded,
                selected: selectedPosition == TirePosition.rear,
                onTap: () => onPositionChanged(TirePosition.rear),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

Widget _positionButton({
  required String label,
  required IconData icon,
  required bool selected,
  required VoidCallback onTap,
}) {
  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(14),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: selected ? AppColors.primaryMuted : AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: selected ? AppColors.primary : AppColors.edge, width: selected ? 1.4 : 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 17, color: selected ? AppColors.primaryDeep : AppColors.inkMuted),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.5,
                color: selected ? AppColors.primaryDeep : AppColors.inkMuted,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _quickScanCard(BuildContext rootContext, BuildContext sheetContext, _InspectionContext inspectionContext) {
  return _inspectionModeCard(
    icon: Icons.bolt_rounded,
    iconBg: AppColors.primaryMuted,
    iconColor: AppColors.primaryHover,
    title: 'Quick scan',
    subtitle: 'Use one clear photo to screen for visible tire wear or damage.',
    badges: const ['1 photo', 'Fast', 'Low coverage'],
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _modeNote(
          icon: Icons.info_outline_rounded,
          text: 'Best for obvious issues. A clean quick scan still cannot prove the whole tire is safe.',
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.pop(sheetContext);
                  _runQuickInspection(rootContext, ImageSource.camera, inspectionContext);
                },
                icon: const Icon(Icons.photo_camera_rounded, size: 18),
                label: const Text('Camera'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(46),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(sheetContext);
                  _runQuickInspection(rootContext, ImageSource.gallery, inspectionContext);
                },
                icon: const Icon(Icons.photo_library_rounded, size: 18),
                label: const Text('Upload'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(46),
                  foregroundColor: AppColors.primaryDeep,
                  side: BorderSide(color: AppColors.primary, width: 1.2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

Widget _guidedFullCheckCard(BuildContext rootContext, BuildContext sheetContext, _InspectionContext inspectionContext) {
  return _inspectionModeCard(
    icon: Icons.fact_check_rounded,
    iconBg: AppColors.successBg,
    iconColor: AppColors.success,
    title: 'Guided full check',
    subtitle: 'Capture or upload 5 guided tire views so AI can judge the result with better context.',
    badges: const ['5 photos', 'Camera or upload', 'Recommended'],
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 2),
        _guidedPreviewGrid(),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: FilledButton.icon(
            onPressed: () {
              Navigator.pop(sheetContext);
              _runGuidedFullCheck(rootContext, inspectionContext);
            },
            icon: const Icon(Icons.play_arrow_rounded, size: 20),
            label: const Text('Start guided check'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.success,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
              textStyle: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ],
    ),
  );
}

Widget _inspectionModeCard({
  required IconData icon,
  required Color iconBg,
  required Color iconColor,
  required String title,
  required String subtitle,
  required List<String> badges,
  required Widget child,
}) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppColors.edge),
      boxShadow: [BoxShadow(color: AppColors.primaryDeep.withValues(alpha: 0.05), blurRadius: 16, offset: const Offset(0, 8))],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(13)),
              child: Icon(icon, size: 23, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.poppins(fontSize: 15.5, fontWeight: FontWeight.w800, color: AppColors.ink)),
                  const SizedBox(height: 3),
                  Text(subtitle, style: TextStyle(fontSize: 12.5, color: AppColors.inkMuted, height: 1.35, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: badges.map(_modeBadge).toList(growable: false),
        ),
        const SizedBox(height: 13),
        child,
      ],
    ),
  );
}

Widget _modeBadge(String label) {
  final recommended = label.toLowerCase().contains('recommended');
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: recommended ? AppColors.successBg : AppColors.fieldFill,
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: recommended ? AppColors.success.withValues(alpha: 0.25) : AppColors.edge),
    ),
    child: Text(
      label,
      style: TextStyle(
        fontSize: 11,
        color: recommended ? AppColors.success : AppColors.inkMuted,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

Widget _modeNote({
  required IconData icon,
  required String text,
}) {
  return Container(
    padding: const EdgeInsets.all(11),
    decoration: BoxDecoration(color: AppColors.warningBg, borderRadius: BorderRadius.circular(13)),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.warning),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 12, color: AppColors.warning, height: 1.32, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}

Widget _guidedPreviewGrid() {
  return Column(
    children: [
      Row(
        children: [
          Expanded(child: _guidedPreviewItem(_guidedTireSteps[0])),
          const SizedBox(width: 8),
          Expanded(child: _guidedPreviewItem(_guidedTireSteps[1])),
        ],
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(child: _guidedPreviewItem(_guidedTireSteps[2])),
          const SizedBox(width: 8),
          Expanded(child: _guidedPreviewItem(_guidedTireSteps[3])),
        ],
      ),
      const SizedBox(height: 8),
      _guidedPreviewItem(_guidedTireSteps[4]),
    ],
  );
}

Widget _guidedPreviewItem(_GuidedCaptureStep step) {
  return Container(
    constraints: const BoxConstraints(minHeight: 42),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
    decoration: BoxDecoration(
      color: AppColors.fieldFill,
      borderRadius: BorderRadius.circular(13),
      border: Border.all(color: AppColors.edge),
    ),
    child: Row(
      children: [
        Icon(step.icon, size: 17, color: AppColors.primary),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            step.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11.5, color: AppColors.ink, fontWeight: FontWeight.w700, height: 1.15),
          ),
        ),
      ],
    ),
  );
}

Future<void> _runQuickInspection(BuildContext context, ImageSource source, _InspectionContext inspectionContext) async {
  final bytes = await _pickImageBytes(context, source);
  if (bytes == null || !context.mounted) return;

  _showLoadingDialog(context, message: 'Analyzing quick scan and preparing estimate...');

  DamageReport report;
  _QuoteLoadResult quoteResult = const _QuoteLoadResult();
  try {
    report = await VisionApiService.analyze(bytes);
    quoteResult = await _loadQuoteIfNeeded(context, report, inspectionContext);
  } on AiException catch (e) {
    if (context.mounted) Navigator.pop(context);
    if (context.mounted) _showErrorDialog(context, e.message);
    return;
  } catch (_) {
    if (context.mounted) Navigator.pop(context);
    if (context.mounted) _showErrorDialog(context, 'Could not analyze the photo. Please try again.');
    return;
  }

  if (!context.mounted) return;
  Navigator.pop(context);
  _openResult(
    context,
    images: [bytes],
    report: report,
    inspectionContext: inspectionContext,
    tireRecommendation: quoteResult.recommendation,
    quoteError: quoteResult.error,
  );
}

Future<void> _runGuidedFullCheck(BuildContext context, _InspectionContext inspectionContext) async {
  final picker = ImagePicker();
  final captures = <_CapturedInspectionPhoto>[];

  while (captures.length < _guidedTireSteps.length) {
    final step = _guidedTireSteps[captures.length];
    final source = await _showGuidedStepDialog(
      context,
      step: step,
      index: captures.length + 1,
      total: _guidedTireSteps.length,
    );

    if (source == null || !context.mounted) return;

    XFile? file;
    try {
      file = await picker.pickImage(source: source, imageQuality: 72, maxWidth: 1280);
    } catch (_) {
      if (context.mounted) {
        _showErrorDialog(
          context,
          source == ImageSource.camera
              ? 'Could not open the camera. Please try again.'
              : 'Could not open the gallery. Please try again.',
        );
      }
      return;
    }

    if (file == null) {
      final retry = await _showRetryPhotoDialog(context);
      if (!context.mounted) return;
      if (retry == true) continue;
      return;
    }

    Uint8List imageBytes;
    try {
      imageBytes = await file.readAsBytes();
    } catch (_) {
      if (context.mounted) _showErrorDialog(context, 'Could not read the photo. Please try again.');
      return;
    }

    try {
      await VisionApiService.precheck(imageBytes, sourceView: step.title);
    } on AiException catch (e) {
      if (!context.mounted) return;
      final retry = await _showInvalidPhotoDialog(context, e.message);
      if (!context.mounted) return;
      if (retry == true) continue;
      return;
    } catch (_) {
      if (!context.mounted) return;
      final retry = await _showInvalidPhotoDialog(
        context,
        'Could not verify this photo. Please use a clear tire photo for this step.',
      );
      if (!context.mounted) return;
      if (retry == true) continue;
      return;
    }

    captures.add(_CapturedInspectionPhoto(
      imageBytes: imageBytes,
      viewName: step.title,
    ));
  }

  if (!context.mounted) return;
  _showLoadingDialog(context, message: 'Analyzing ${captures.length} guided photos and preparing estimate...');

  DamageReport report;
  _QuoteLoadResult quoteResult = const _QuoteLoadResult();
  try {
    report = await VisionApiService.analyzeGuided(
      captures
          .map((photo) => VisionPhotoInput(
                imageBytes: photo.imageBytes,
                viewName: photo.viewName,
              ))
          .toList(growable: false),
    );
    quoteResult = await _loadQuoteIfNeeded(context, report, inspectionContext);
  } on AiException catch (e) {
    if (context.mounted) Navigator.pop(context);
    if (context.mounted) _showErrorDialog(context, e.message);
    return;
  } catch (_) {
    if (context.mounted) Navigator.pop(context);
    if (context.mounted) _showErrorDialog(context, 'Could not analyze the guided photos. Please try again.');
    return;
  }

  if (!context.mounted) return;
  Navigator.pop(context);
  _openResult(
    context,
    images: captures.map((photo) => photo.imageBytes).toList(growable: false),
    report: report,
    inspectionContext: inspectionContext,
    tireRecommendation: quoteResult.recommendation,
    quoteError: quoteResult.error,
  );
}

Future<Uint8List?> _pickImageBytes(BuildContext context, ImageSource source) async {
  try {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: source, imageQuality: 72, maxWidth: 1280);
    if (file == null) return null;
    return file.readAsBytes();
  } catch (_) {
    if (context.mounted) _showErrorDialog(context, 'Could not open the image. Please try again.');
    return null;
  }
}

void _openResult(
  BuildContext context, {
  required List<Uint8List> images,
  required DamageReport report,
  required _InspectionContext inspectionContext,
  TireRecommendation? tireRecommendation,
  String? quoteError,
}) {
  if (!report.relevant || report.component == 'unknown') {
    _showErrorDialog(
      context,
      report.summary.isNotEmpty
          ? report.summary
          : "That photo doesn't look like a motorbike, tire, or brake pad. Please take a clear photo of your bike, tire, or brake pad.",
    );
    return;
  }

  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => InspectionResultScreen(
        images: images,
        report: report,
        tireRecommendation: tireRecommendation,
        quoteError: quoteError,
        onStartGuidedCheck: report.mode == InspectionMode.quickScan ? () => _runGuidedFullCheck(context, inspectionContext) : null,
      ),
    ),
  );
}

Future<List<Vehicle>> _loadVehiclesForInspection(BuildContext context) async {
  final userId = _currentCustomerId(context.read<AuthProvider>().mysqlUser);
  if (userId == null) {
    throw Exception('Login info not found.');
  }

  final response = await ApiClient.get('/vehicles/owner/$userId');
  final decoded = ApiClient.parseResponse(response);
  if (decoded is! List) return const [];

  return decoded
      .whereType<Map>()
      .map((vehicle) => Vehicle.fromJson(Map<String, dynamic>.from(vehicle)))
      .where((vehicle) => vehicle.id != null)
      .toList(growable: false);
}

int? _currentCustomerId(Map<String, dynamic>? user) {
  final value = user?['userId'] ?? user?['id'] ?? user?['user']?['id'];
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}

Future<_QuoteLoadResult> _loadQuoteIfNeeded(
  BuildContext context,
  DamageReport report,
  _InspectionContext inspectionContext,
) async {
  if (!report.recommendService || report.component != 'tire') {
    return const _QuoteLoadResult();
  }

  final vehicleId = inspectionContext.vehicle.id;
  if (vehicleId == null) {
    return const _QuoteLoadResult(error: 'Could not prepare an estimate because the selected vehicle is missing an ID.');
  }

  try {
    final recommendation = await TireRecommendationService.getRecommendation(
      vehicleId: vehicleId,
      position: inspectionContext.tirePosition,
    );
    return _QuoteLoadResult(recommendation: recommendation);
  } on TireRecommendationException catch (e) {
    return _QuoteLoadResult(error: e.message);
  } catch (_) {
    return const _QuoteLoadResult(error: 'Could not prepare the tire estimate. Please try again later.');
  }
}

String _vehicleDisplayName(Vehicle vehicle) {
  final model = [vehicle.brand, vehicle.vehicleName].where((part) => part.trim().isNotEmpty).join(' ');
  final plate = vehicle.licensePlate.trim();
  if (plate.isEmpty) return model.isEmpty ? 'Selected vehicle' : model;
  return model.isEmpty ? plate : '$model - $plate';
}

void _showNoVehicleDialog(BuildContext context, {VoidCallback? onOpenVehicles}) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: AppColors.warningBg, borderRadius: BorderRadius.circular(12)),
            child: Icon(Icons.motorcycle_outlined, color: AppColors.warning, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Add a vehicle first',
              style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.ink),
            ),
          ),
        ],
      ),
      content: Text(
        'CareBike needs your saved vehicle before scanning so it can choose the correct front or rear tire size and prepare a transparent estimate.',
        style: TextStyle(fontSize: 14, color: AppColors.ink, height: 1.4),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Later'),
        ),
        FilledButton.icon(
          onPressed: () {
            Navigator.pop(ctx);
            onOpenVehicles?.call();
          },
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('My Vehicles'),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    ),
  );
}

Future<ImageSource?> _showGuidedStepDialog(
  BuildContext context, {
  required _GuidedCaptureStep step,
  required int index,
  required int total,
}) {
  return showDialog<ImageSource>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: AppColors.primaryMuted, borderRadius: BorderRadius.circular(13)),
            child: Icon(step.icon, color: AppColors.primaryHover, size: 23),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Photo $index of $total',
                  style: TextStyle(fontSize: 12, color: AppColors.inkMuted, fontWeight: FontWeight.w700),
                ),
                Text(
                  step.title,
                  style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.ink),
                ),
              ],
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 6,
              value: index / total,
              backgroundColor: AppColors.edgeSoft,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
          const SizedBox(height: 14),
          Text(step.instruction, style: TextStyle(fontSize: 14, color: AppColors.ink, height: 1.4)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(color: AppColors.fieldFill, borderRadius: BorderRadius.circular(13)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.light_mode_outlined, size: 16, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Use good light, keep the tire sharp, and choose a saved photo only if it matches this angle.',
                    style: TextStyle(fontSize: 12, color: AppColors.inkMuted, height: 1.3, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Stop'),
        ),
        OutlinedButton.icon(
          onPressed: () => Navigator.pop(ctx, ImageSource.gallery),
          icon: const Icon(Icons.photo_library_rounded, size: 18),
          label: const Text('Upload'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primaryDeep,
            side: BorderSide(color: AppColors.primary, width: 1.2),
          ),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.pop(ctx, ImageSource.camera),
          icon: const Icon(Icons.photo_camera_rounded, size: 18),
          label: const Text('Take photo'),
        ),
      ],
    ),
  );
}

Future<bool?> _showRetryPhotoDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        'No photo captured',
        style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ink),
      ),
      content: Text(
        'Try this angle again to complete the guided check.',
        style: TextStyle(fontSize: 14, color: AppColors.ink, height: 1.4),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Stop'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Try again'),
        ),
      ],
    ),
  );
}

Future<bool?> _showInvalidPhotoDialog(BuildContext context, String message) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: AppColors.warningBg, borderRadius: BorderRadius.circular(12)),
            child: Icon(Icons.photo_camera_back_outlined, color: AppColors.warning, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Photo not accepted',
              style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.ink),
            ),
          ),
        ],
      ),
      content: Text(message, style: TextStyle(fontSize: 14, color: AppColors.ink, height: 1.4)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Stop'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Try again'),
        ),
      ],
    ),
  );
}

void _showLoadingDialog(BuildContext context, {required String message}) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 22),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(width: 30, height: 30, child: CircularProgressIndicator(strokeWidth: 2.6, color: AppColors.primary)),
            const SizedBox(height: 16),
            Text(message, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.ink)),
          ],
        ),
      ),
    ),
  );
}

void _showErrorDialog(BuildContext context, String message) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: AppColors.dangerBg, borderRadius: BorderRadius.circular(12)),
            child: Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 23),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              "Can't inspect",
              style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.ink),
            ),
          ),
        ],
      ),
      content: Text(message, style: TextStyle(fontSize: 14, color: AppColors.ink, height: 1.4)),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(ctx),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('Try again'),
        ),
      ],
    ),
  );
}

class _GuidedCaptureStep {
  final String title;
  final String instruction;
  final IconData icon;

  const _GuidedCaptureStep({
    required this.title,
    required this.instruction,
    required this.icon,
  });
}

class _CapturedInspectionPhoto {
  final Uint8List imageBytes;
  final String viewName;

  const _CapturedInspectionPhoto({
    required this.imageBytes,
    required this.viewName,
  });
}

class _InspectionContext {
  final Vehicle vehicle;
  final TirePosition tirePosition;

  const _InspectionContext({
    required this.vehicle,
    required this.tirePosition,
  });
}

class _QuoteLoadResult {
  final TireRecommendation? recommendation;
  final String? error;

  const _QuoteLoadResult({
    this.recommendation,
    this.error,
  });
}
