import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:mobile_app/core/theme/theme.dart';
import 'package:mobile_app/features/inspection/models/damage_models.dart';
import 'package:mobile_app/features/inspection/models/tire_quote_models.dart';

/// Shows the AI inspection result for a tire / brake pad photo set.
class InspectionResultScreen extends StatelessWidget {
  final List<Uint8List> images;
  final DamageReport report;
  final TireRecommendation? tireRecommendation;
  final String? quoteError;
  final VoidCallback? onStartGuidedCheck;

  InspectionResultScreen({
    super.key,
    required this.images,
    required this.report,
    this.tireRecommendation,
    this.quoteError,
    this.onStartGuidedCheck,
  }) : assert(images.isNotEmpty);

  String get _componentLabel {
    switch (report.component) {
      case 'bike':
        return 'Motorbike';
      case 'tire':
        return 'Tire';
      case 'brake_pad':
        return 'Brake pad';
      default:
        return 'Component';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: const Text('Inspection result'),
        titleTextStyle: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ink),
        centerTitle: true,
        backgroundColor: AppColors.canvas,
        foregroundColor: AppColors.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          _photoPreview(),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _plainChip(_componentLabel, AppColors.primaryMuted, AppColors.primaryDeep),
              _plainChip(report.modeLabel, AppColors.fieldFill, AppColors.ink),
              _verdictChip(),
            ],
          ),
          const SizedBox(height: 16),
          _metricRow(),
          const SizedBox(height: 14),
          _summaryCard(),
          const SizedBox(height: 14),
          _decisionCard(),
          if (tireRecommendation != null || quoteError != null) ...[
            const SizedBox(height: 14),
            _transparentQuoteCard(),
          ],
          if (report.capturedViews.isNotEmpty) ...[
            const SizedBox(height: 14),
            _capturedViewsCard(),
          ],
          if (report.hasDamage && report.items.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text('Findings', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.ink)),
            const SizedBox(height: 12),
            ...report.items.map(_itemCard),
          ],
          const SizedBox(height: 18),
          _disclaimerCard(),
          if (report.mode == InspectionMode.quickScan && onStartGuidedCheck != null) ...[
            const SizedBox(height: 18),
            SizedBox(
              height: 52,
              child: OutlinedButton.icon(
                onPressed: () => _startGuidedFromResult(context),
                icon: const Icon(Icons.fact_check_rounded, size: 19),
                label: const Text('Run guided full check'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primaryDeep,
                  side: BorderSide(color: AppColors.primary, width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  textStyle: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
          if (report.recommendService) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: const LinearGradient(colors: [Color(0xFFFB923C), Color(0xFFF97316), Color(0xFFEA580C)]),
                  boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.5), blurRadius: 22, offset: const Offset(0, 11))],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.event_available_rounded, size: 20, color: Colors.white),
                    SizedBox(width: 8),
                    Text('Book a service', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          SizedBox(
            height: 50,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.check_rounded, size: 19),
              label: const Text('Done'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryDeep,
                side: BorderSide(color: AppColors.primary, width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                textStyle: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _photoPreview() {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Image.memory(
            images.first,
            height: 210,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
        ),
        if (images.length > 1)
          Positioned(
            right: 12,
            bottom: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.68),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '${images.length} photos',
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800),
              ),
            ),
          ),
      ],
    );
  }

  Widget _metricRow() {
    return Row(
      children: [
        Expanded(
          child: _metricTile(
            icon: Icons.analytics_outlined,
            title: 'Detection confidence',
            value: report.detectionConfidenceLabel,
            caption: report.hasDamage ? 'Highest visible issue' : 'No issue detected',
            color: report.hasDamage ? AppColors.danger : AppColors.success,
            bg: report.hasDamage ? AppColors.dangerBg : AppColors.successBg,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _metricTile(
            icon: Icons.photo_library_outlined,
            title: 'Inspection completeness',
            value: report.coverageLabel,
            caption: report.coverageDescription,
            color: _coverageColor(),
            bg: _coverageColor().withValues(alpha: 0.12),
          ),
        ),
      ],
    );
  }

  Widget _metricTile({
    required IconData icon,
    required String title,
    required String value,
    required String caption,
    required Color color,
    required Color bg,
  }) {
    return Container(
      constraints: const BoxConstraints(minHeight: 118),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.edge),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(height: 10),
          Text(value, style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.ink)),
          const SizedBox(height: 2),
          Text(title, style: TextStyle(fontSize: 11.5, color: AppColors.inkMuted, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(caption, style: TextStyle(fontSize: 11, color: AppColors.faint, height: 1.25, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _summaryCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.edge),
        boxShadow: [BoxShadow(color: AppColors.primaryDeep.withValues(alpha: 0.06), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Text(
        report.summary,
        style: TextStyle(fontSize: 13.5, color: AppColors.ink, height: 1.45, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _decisionCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: report.hasDamage ? AppColors.danger.withValues(alpha: 0.35) : AppColors.edge),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: report.hasDamage ? AppColors.dangerBg : AppColors.successBg,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  report.hasDamage ? Icons.priority_high_rounded : Icons.check_circle_outline_rounded,
                  size: 20,
                  color: report.hasDamage ? AppColors.danger : AppColors.success,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(report.decisionTitle, style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.ink)),
                    const SizedBox(height: 4),
                    Text(report.decisionMessage, style: TextStyle(fontSize: 13, color: AppColors.inkMuted, height: 1.35, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(color: AppColors.edge, height: 1),
          const SizedBox(height: 12),
          _decisionLine(Icons.route_rounded, 'Ride advice', report.rideAdvice),
          const SizedBox(height: 10),
          _decisionLine(Icons.task_alt_rounded, 'Next step', report.nextAction),
        ],
      ),
    );
  }

  Widget _decisionLine(IconData icon, String label, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 17, color: AppColors.primary),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: TextStyle(fontSize: 12.5, color: AppColors.inkMuted, height: 1.35, fontWeight: FontWeight.w500),
              children: [
                TextSpan(text: '$label: ', style: TextStyle(color: AppColors.ink, fontWeight: FontWeight.w800)),
                TextSpan(text: text),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _transparentQuoteCard() {
    final recommendation = tireRecommendation;
    if (recommendation == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.warning.withValues(alpha: 0.32)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: AppColors.warningBg, borderRadius: BorderRadius.circular(11)),
              child: Icon(Icons.receipt_long_outlined, size: 19, color: AppColors.warning),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Estimate unavailable', style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.ink)),
                  const SizedBox(height: 4),
                  Text(
                    quoteError ?? 'CareBike could not prepare a tire estimate for this result.',
                    style: TextStyle(fontSize: 13, color: AppColors.inkMuted, height: 1.35, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final options = recommendation.options.take(3).toList(growable: false);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
        boxShadow: [BoxShadow(color: AppColors.primaryDeep.withValues(alpha: 0.06), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: AppColors.primaryMuted, borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.request_quote_outlined, size: 20, color: AppColors.primaryDeep),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Transparent estimate', style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.ink)),
                    const SizedBox(height: 4),
                    Text(
                      '${recommendation.brand} ${recommendation.vehicleName} - ${recommendation.tirePosition.label} - ${recommendation.tireSize}',
                      style: TextStyle(fontSize: 12.5, color: AppColors.inkMuted, height: 1.35, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (options.isEmpty)
            _quoteEmptyState(recommendation)
          else
            ...options.map(_quoteOptionTile),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(color: AppColors.fieldFill, borderRadius: BorderRadius.circular(13)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded, size: 16, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    recommendation.quoteDisclaimer,
                    style: TextStyle(fontSize: 11.8, color: AppColors.inkMuted, height: 1.32, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _quoteEmptyState(TireRecommendation recommendation) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(color: AppColors.warningBg, borderRadius: BorderRadius.circular(14)),
      child: Text(
        'No tire in the catalog currently matches size ${recommendation.tireSize}. A branch can confirm alternatives manually.',
        style: TextStyle(fontSize: 12.5, color: AppColors.warning, height: 1.35, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _quoteOptionTile(TireQuoteOption option) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.fieldFill,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AppColors.edge),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(11)),
                child: Icon(Icons.album_rounded, size: 19, color: AppColors.primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      option.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(fontSize: 13.2, fontWeight: FontWeight.w800, color: AppColors.ink, height: 1.22),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Fit confidence ${option.fitConfidence}% - ${option.tireSize}',
                      style: TextStyle(fontSize: 11.6, color: AppColors.inkMuted, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 11),
          _quotePriceLine('Tire', _money(option.price)),
          const SizedBox(height: 6),
          _quotePriceLine('Labor estimate', '${_money(option.laborMin)} - ${_money(option.laborMax)}'),
          const SizedBox(height: 8),
          Divider(color: AppColors.edge, height: 1),
          const SizedBox(height: 8),
          _quotePriceLine(
            'Estimated total',
            '${_money(option.estimateMin)} - ${_money(option.estimateMax)}',
            strong: true,
          ),
        ],
      ),
    );
  }

  Widget _quotePriceLine(String label, String value, {bool strong = false}) {
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

  String _money(double value) {
    return '${NumberFormat.decimalPattern('vi_VN').format(value)} VND';
  }

  Widget _capturedViewsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.fieldFill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.edge),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Photos checked', style: GoogleFonts.poppins(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppColors.ink)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: report.capturedViews
                .map((view) => _plainChip(view, AppColors.surface, AppColors.inkMuted))
                .toList(growable: false),
          ),
        ],
      ),
    );
  }

  Widget _disclaimerCard() {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(color: AppColors.warningBg, borderRadius: BorderRadius.circular(14)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 17, color: AppColors.warning),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              'AI checks visible signs only. Quick scan uses one photo; guided check improves coverage but does not replace a professional safety inspection.',
              style: TextStyle(fontSize: 12, color: AppColors.warning, height: 1.35, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _verdictChip() {
    final ok = !report.hasDamage;
    final color = ok ? AppColors.success : AppColors.danger;
    final bg = ok ? AppColors.successBg : AppColors.dangerBg;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(ok ? Icons.visibility_outlined : Icons.warning_amber_rounded, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            ok ? 'No obvious issue' : 'Needs attention',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color),
          ),
        ],
      ),
    );
  }

  Widget _plainChip(String label, Color bg, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.edge),
      ),
      child: Text(label, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
    );
  }

  Widget _itemCard(DamageItem it) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.edge),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  it.part.isEmpty ? 'Damage' : it.part,
                  style: GoogleFonts.poppins(fontSize: 14.5, fontWeight: FontWeight.w800, color: AppColors.ink),
                ),
              ),
              _severityChip(it.severity),
            ],
          ),
          if (it.issue.isNotEmpty) ...[
            const SizedBox(height: 7),
            Text(it.issue, style: TextStyle(fontSize: 13, color: AppColors.ink, height: 1.35)),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _miniMeta(Icons.photo_camera_outlined, it.sourceView),
              _miniMeta(Icons.percent_rounded, '${(it.confidence * 100).round()}% AI confidence'),
            ],
          ),
          if (it.suggestion.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.build_circle_outlined, size: 15, color: AppColors.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(it.suggestion, style: TextStyle(fontSize: 12.5, color: AppColors.inkMuted, height: 1.3, fontWeight: FontWeight.w500)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _miniMeta(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(color: AppColors.fieldFill, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.inkMuted),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(fontSize: 11, color: AppColors.inkMuted, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _severityChip(String sev) {
    final s = sev.toLowerCase();
    Color color;
    String label;
    if (s.contains('severe')) {
      color = AppColors.danger;
      label = 'Severe';
    } else if (s.contains('moderate')) {
      color = const Color(0xFFF59E0B);
      label = 'Moderate';
    } else if (s.contains('minor')) {
      color = AppColors.success;
      label = 'Minor';
    } else {
      color = AppColors.inkMuted;
      label = 'Unknown';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
      child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 11)),
    );
  }

  Color _coverageColor() {
    switch (report.coverageLevel) {
      case InspectionCoverageLevel.low:
        return AppColors.warning;
      case InspectionCoverageLevel.medium:
        return AppColors.info;
      case InspectionCoverageLevel.high:
        return AppColors.success;
    }
  }

  void _startGuidedFromResult(BuildContext context) {
    final start = onStartGuidedCheck;
    if (start == null) return;
    Navigator.pop(context);
    WidgetsBinding.instance.addPostFrameCallback((_) => start());
  }
}
