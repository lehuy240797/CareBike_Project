import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import 'package:mobile_app/core/theme/theme.dart';
import 'package:mobile_app/features/inspection/models/damage_models.dart';
import 'package:mobile_app/features/inspection/models/tire_quote_models.dart';
import 'package:mobile_app/features/inspection/models/vehicle_tire_spec_models.dart';
import 'package:mobile_app/features/inspection/services/tire_recommendation_service.dart';
import 'package:mobile_app/features/inspection/services/vehicle_tire_spec_service.dart';
import 'package:mobile_app/features/inspection/services/vision_api_service.dart';

class BranchTireAssistantScreen extends StatefulWidget {
  const BranchTireAssistantScreen({super.key});

  @override
  State<BranchTireAssistantScreen> createState() => _BranchTireAssistantScreenState();
}

class _BranchTireAssistantScreenState extends State<BranchTireAssistantScreen> {
  final _moneyFormat = NumberFormat.decimalPattern('vi_VN');

  bool _loadingSpecs = true;
  bool _analyzing = false;
  String? _loadError;
  List<VehicleTireSpec> _specs = const [];
  VehicleTireSpec? _selectedSpec;
  TirePosition _selectedPosition = TirePosition.rear;

  Uint8List? _imageBytes;
  DamageReport? _report;
  TireRecommendation? _recommendation;
  String? _quoteError;

  @override
  void initState() {
    super.initState();
    _loadSpecs();
  }

  Future<void> _loadSpecs() async {
    setState(() {
      _loadingSpecs = true;
      _loadError = null;
    });

    try {
      final specs = await VehicleTireSpecService.getAll();
      if (!mounted) return;
      setState(() {
        _specs = specs;
        _selectedSpec = specs.isEmpty ? null : specs.first;
        _loadingSpecs = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingSpecs = false;
        _loadError = 'Could not load vehicle tire specs.';
      });
    }
  }

  Future<void> _pickAndAnalyze(ImageSource source) async {
    final spec = _selectedSpec;
    if (spec == null) {
      _showSnack('Please choose a vehicle spec first.', danger: true);
      return;
    }

    XFile? file;
    try {
      file = await ImagePicker().pickImage(source: source, imageQuality: 72, maxWidth: 1280);
    } catch (_) {
      _showSnack(source == ImageSource.camera ? 'Could not open the camera.' : 'Could not open the gallery.', danger: true);
      return;
    }

    if (file == null) return;

    Uint8List bytes;
    try {
      bytes = await file.readAsBytes();
    } catch (_) {
      _showSnack('Could not read this photo.', danger: true);
      return;
    }

    setState(() {
      _analyzing = true;
      _imageBytes = bytes;
      _report = null;
      _recommendation = null;
      _quoteError = null;
    });

    try {
      await VisionApiService.precheck(bytes, sourceView: 'Technician photo');
      final report = await VisionApiService.analyze(
        bytes,
        sourceView: 'Technician photo',
        verifyPhoto: false,
      );

      TireRecommendation? recommendation;
      String? quoteError;
      if (report.component == 'tire' && report.hasDamage) {
        try {
          recommendation = await TireRecommendationService.getRecommendationBySpec(
            specId: spec.id,
            position: _selectedPosition,
          );
        } on TireRecommendationException catch (e) {
          quoteError = e.message;
        } catch (_) {
          quoteError = 'Could not prepare replacement options.';
        }
      }

      if (!mounted) return;
      setState(() {
        _report = report;
        _recommendation = recommendation;
        _quoteError = quoteError;
        _analyzing = false;
      });
    } on AiException catch (e) {
      if (!mounted) return;
      setState(() => _analyzing = false);
      _showSnack(e.message, danger: true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _analyzing = false);
      _showSnack('Could not analyze this photo.', danger: true);
    }
  }

  void _showSnack(String message, {bool danger = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: danger ? AppColors.danger : AppColors.primary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: const Text('AI tire assistant'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            _heroCard(),
            const SizedBox(height: 14),
            _setupCard(),
            const SizedBox(height: 14),
            _scanCard(),
            if (_report != null) ...[
              const SizedBox(height: 14),
              _resultCard(_report!),
            ],
            if (_recommendation != null || _quoteError != null || (_report != null && !_report!.hasDamage)) ...[
              const SizedBox(height: 14),
              _replacementCard(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _heroCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppStyles.brandGradient,
        borderRadius: BorderRadius.circular(22),
        boxShadow: AppStyles.glow,
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(Icons.center_focus_strong_rounded, color: Colors.white, size: 25),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Branch tire scan',
                  style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white),
                ),
                const SizedBox(height: 4),
                Text(
                  'Quick AI support for tire checks and replacement options.',
                  style: TextStyle(fontSize: 12.5, height: 1.35, color: Colors.white.withValues(alpha: 0.88), fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _setupCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppStyles.card(radius: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(Icons.two_wheeler_rounded, 'Vehicle setup'),
          const SizedBox(height: 13),
          if (_loadingSpecs)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_loadError != null)
            _inlineNotice(_loadError!, AppColors.dangerBg, AppColors.danger)
          else if (_specs.isEmpty)
            _inlineNotice('No tire specs found. Add vehicle tire specs in Admin first.', AppColors.warningBg, AppColors.warning)
          else ...[
            DropdownButtonFormField<VehicleTireSpec>(
              value: _selectedSpec,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Vehicle spec',
                prefixIcon: Icon(Icons.motorcycle_rounded),
              ),
              items: _specs
                  .map(
                    (spec) => DropdownMenuItem<VehicleTireSpec>(
                      value: spec,
                      child: Text(
                        '${spec.modelLabel} - ${spec.engineLabel}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: AppColors.ink, fontWeight: FontWeight.w700),
                      ),
                    ),
                  )
                  .toList(growable: false),
              onChanged: _analyzing
                  ? null
                  : (value) {
                      setState(() {
                        _selectedSpec = value;
                        _report = null;
                        _imageBytes = null;
                        _recommendation = null;
                        _quoteError = null;
                      });
                    },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _positionButton(TirePosition.front)),
                const SizedBox(width: 10),
                Expanded(child: _positionButton(TirePosition.rear)),
              ],
            ),
            const SizedBox(height: 12),
            _specSizeLine(),
          ],
        ],
      ),
    );
  }

  Widget _positionButton(TirePosition position) {
    final selected = _selectedPosition == position;
    return InkWell(
      onTap: _analyzing
          ? null
          : () {
              setState(() {
                _selectedPosition = position;
                _report = null;
                _imageBytes = null;
                _recommendation = null;
                _quoteError = null;
              });
            },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.fieldFill,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? AppColors.primary : AppColors.edge),
        ),
        child: Text(
          position == TirePosition.front ? 'Front tire' : 'Rear tire',
          style: TextStyle(
            color: selected ? Colors.white : AppColors.ink,
            fontWeight: FontWeight.w800,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _specSizeLine() {
    final spec = _selectedSpec;
    if (spec == null) return const SizedBox.shrink();
    final size = _selectedPosition == TirePosition.front ? spec.frontTireSize : spec.rearTireSize;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          Icon(Icons.album_rounded, size: 18, color: AppColors.primaryDeep),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Target size: $size',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12.5, color: AppColors.primaryDeep, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  Widget _scanCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppStyles.card(radius: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(Icons.photo_camera_rounded, 'Photo scan'),
          const SizedBox(height: 13),
          _photoPreview(),
          const SizedBox(height: 13),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _analyzing || _loadingSpecs ? null : () => _pickAndAnalyze(ImageSource.camera),
                  icon: const Icon(Icons.photo_camera_rounded, size: 18),
                  label: const Text('Take photo'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _analyzing || _loadingSpecs ? null : () => _pickAndAnalyze(ImageSource.gallery),
                  icon: const Icon(Icons.image_rounded, size: 18),
                  label: const Text('Upload'),
                ),
              ),
            ],
          ),
          if (_analyzing) ...[
            const SizedBox(height: 13),
            LinearProgressIndicator(
              color: AppColors.primary,
              backgroundColor: AppColors.primaryMuted,
              borderRadius: BorderRadius.circular(20),
            ),
          ],
        ],
      ),
    );
  }

  Widget _photoPreview() {
    final bytes = _imageBytes;
    if (bytes == null) {
      return Container(
        height: 168,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.fieldFill,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.edge),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_a_photo_outlined, color: AppColors.primary, size: 30),
            const SizedBox(height: 8),
            Text(
              'No photo selected',
              style: TextStyle(color: AppColors.inkMuted, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Image.memory(
        bytes,
        height: 188,
        width: double.infinity,
        fit: BoxFit.cover,
      ),
    );
  }

  Widget _resultCard(DamageReport report) {
    final color = report.hasDamage ? (report.recommendService ? AppColors.danger : AppColors.warning) : AppColors.success;
    final bg = report.hasDamage ? (report.recommendService ? AppColors.dangerBg : AppColors.warningBg) : AppColors.successBg;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppStyles.card(radius: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(13)),
                child: Icon(report.hasDamage ? Icons.report_problem_outlined : Icons.check_circle_outline_rounded, color: color, size: 21),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  report.decisionTitle,
                  style: GoogleFonts.poppins(fontSize: 15.5, fontWeight: FontWeight.w800, color: AppColors.ink),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
                child: Text(
                  report.detectionConfidenceLabel,
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: color),
                ),
              ),
            ],
          ),
          const SizedBox(height: 11),
          Text(
            report.summary,
            style: TextStyle(fontSize: 13, height: 1.4, color: AppColors.inkMuted, fontWeight: FontWeight.w600),
          ),
          if (report.items.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...report.items.take(2).map(_findingLine),
          ],
        ],
      ),
    );
  }

  Widget _findingLine(DamageItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: AppColors.fieldFill,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: AppColors.edge),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.album_rounded, color: AppColors.primary, size: 18),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.part, style: TextStyle(fontSize: 13, color: AppColors.ink, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(item.issue, style: TextStyle(fontSize: 12.3, color: AppColors.inkMuted, height: 1.3, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _replacementCard() {
    final recommendation = _recommendation;
    final report = _report;

    if (report != null && !report.hasDamage) {
      return _noticeCard(
        icon: Icons.check_circle_outline_rounded,
        title: 'No replacement suggested',
        message: 'The quick scan did not detect visible tire damage. Confirm manually if the tire has vibration, low pressure, or uneven wear.',
        color: AppColors.success,
        bg: AppColors.successBg,
      );
    }

    if (_quoteError != null) {
      return _noticeCard(
        icon: Icons.receipt_long_outlined,
        title: 'Replacement options unavailable',
        message: _quoteError!,
        color: AppColors.warning,
        bg: AppColors.warningBg,
      );
    }

    if (recommendation == null) return const SizedBox.shrink();
    final options = recommendation.options.take(3).toList(growable: false);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppStyles.card(radius: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(Icons.request_quote_outlined, 'Replacement options'),
          const SizedBox(height: 8),
          Text(
            '${recommendation.brand} ${recommendation.vehicleName} - ${recommendation.tirePosition.label} - ${recommendation.tireSize}',
            style: TextStyle(fontSize: 12.5, color: AppColors.inkMuted, height: 1.35, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 13),
          if (options.isEmpty)
            _inlineNotice(
              'No catalog tire currently matches size ${recommendation.tireSize}.',
              AppColors.warningBg,
              AppColors.warning,
            )
          else
            ...options.map(_quoteOptionTile),
          const SizedBox(height: 10),
          Text(
            recommendation.quoteDisclaimer,
            style: TextStyle(fontSize: 11.6, color: AppColors.inkMuted, height: 1.35, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _quoteOptionTile(TireQuoteOption option) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.fieldFill,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AppColors.edge),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.album_rounded, color: AppColors.primary, size: 20),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  option.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.ink, height: 1.25),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _priceLine('Tire', _money(option.price)),
          const SizedBox(height: 5),
          _priceLine('Labor', '${_money(option.laborMin)} - ${_money(option.laborMax)}'),
          const SizedBox(height: 7),
          Divider(color: AppColors.edge, height: 1),
          const SizedBox(height: 7),
          _priceLine('Estimated total', '${_money(option.estimateMin)} - ${_money(option.estimateMax)}', strong: true),
        ],
      ),
    );
  }

  Widget _noticeCard({
    required IconData icon,
    required String title,
    required String message,
    required Color color,
    required Color bg,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppStyles.card(radius: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(13)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.poppins(fontSize: 14.5, fontWeight: FontWeight.w800, color: AppColors.ink)),
                const SizedBox(height: 4),
                Text(message, style: TextStyle(fontSize: 12.7, color: AppColors.inkMuted, height: 1.35, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(IconData icon, String title) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: AppColors.primaryMuted, borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, size: 19, color: AppColors.primaryDeep),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.ink),
          ),
        ),
      ],
    );
  }

  Widget _inlineNotice(String message, Color bg, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
      child: Text(
        message,
        style: TextStyle(fontSize: 12.5, height: 1.35, color: color, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _priceLine(String label, String value, {bool strong = false}) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: strong ? AppColors.ink : AppColors.inkMuted,
              fontWeight: strong ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: strong ? 13 : 12,
            color: strong ? AppColors.primaryDeep : AppColors.ink,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  String _money(double value) => '${_moneyFormat.format(value)} VND';
}
