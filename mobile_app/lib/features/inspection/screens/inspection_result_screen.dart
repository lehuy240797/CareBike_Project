import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:mobile_app/core/theme/theme.dart';
import 'package:mobile_app/features/inspection/models/damage_models.dart';

/// Shows the AI inspection result for a tire / brake pad photo.
class InspectionResultScreen extends StatelessWidget {
  final Uint8List imageBytes;
  final DamageReport report;

  const InspectionResultScreen({
    super.key,
    required this.imageBytes,
    required this.report,
  });

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
          // Photo
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Image.memory(
              imageBytes,
              height: 210,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 18),

          // Component + verdict chip row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: AppColors.primaryMuted, borderRadius: BorderRadius.circular(20)),
                child: Text(_componentLabel,
                    style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primaryDeep)),
              ),
              const SizedBox(width: 8),
              _verdictChip(),
            ],
          ),
          const SizedBox(height: 16),

          // Summary
          _summaryCard(),

          // Damage items
          if (report.hasDamage && report.items.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text('Findings', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.ink)),
            const SizedBox(height: 12),
            ...report.items.map(_itemCard),
          ],

          const SizedBox(height: 18),
          // Disclaimer
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(color: AppColors.warningBg, borderRadius: BorderRadius.circular(14)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded, size: 17, color: AppColors.warning),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    'This is an AI suggestion based on a single photo — not a professional safety check. Visit a branch for anything serious.',
                    style: TextStyle(fontSize: 12, color: AppColors.warning, height: 1.35, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),

          if (report.recommendService) ...[
            const SizedBox(height: 18),
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
          Icon(ok ? Icons.verified_rounded : Icons.warning_amber_rounded, size: 14, color: color),
          const SizedBox(width: 5),
          Text(ok ? 'Looks good' : 'Damage found',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }

  Widget _summaryCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.edge),
        boxShadow: [BoxShadow(color: AppColors.primaryDeep.withValues(alpha: 0.06), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Text(
        report.summary.isNotEmpty
            ? report.summary
            : (report.hasDamage
                ? 'Some points to check on the photo below.'
                : 'No clear damage detected. It looks fine!'),
        style: TextStyle(fontSize: 14, color: AppColors.ink, height: 1.45, fontWeight: FontWeight.w500),
      ),
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
                child: Text(it.part.isEmpty ? 'Damage' : it.part,
                    style: GoogleFonts.poppins(fontSize: 14.5, fontWeight: FontWeight.w700, color: AppColors.ink)),
              ),
              _severityChip(it.severity),
            ],
          ),
          if (it.issue.isNotEmpty) ...[
            const SizedBox(height: 7),
            Text(it.issue, style: TextStyle(fontSize: 13, color: AppColors.ink, height: 1.35)),
          ],
          if (it.suggestion.isNotEmpty) ...[
            const SizedBox(height: 9),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.build_circle_outlined, size: 15, color: AppColors.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(it.suggestion, style: TextStyle(fontSize: 12.5, color: AppColors.inkMuted, height: 1.3)),
                ),
              ],
            ),
          ],
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
      child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 11)),
    );
  }
}
