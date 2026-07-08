import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import 'package:mobile_app/core/theme/theme.dart';
import 'package:mobile_app/features/inspection/models/damage_models.dart';
import 'package:mobile_app/features/inspection/services/vision_api_service.dart';
import 'package:mobile_app/features/inspection/screens/inspection_result_screen.dart';

/// Shared AI inspection flow (camera/gallery → analyze → result).
/// Used by the Home "Inspect" tile and the customer bottom-bar camera button.

/// Popup to choose camera or gallery, then run the scan.
void openInspectionSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: AppColors.edge, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 18),
            Text('AI inspection', style: GoogleFonts.poppins(fontSize: 19, fontWeight: FontWeight.w800, color: AppColors.ink)),
            const SizedBox(height: 4),
            Text('Scan your bike, tire, or brake pad to check for damage',
                style: TextStyle(fontSize: 13, color: AppColors.inkMuted, fontWeight: FontWeight.w500)),
            const SizedBox(height: 18),
            _sourceTile(
              icon: Icons.photo_camera_rounded,
              title: 'Take a photo',
              subtitle: 'Use your camera',
              onTap: () {
                Navigator.pop(ctx);
                _runInspection(context, ImageSource.camera);
              },
            ),
            const SizedBox(height: 10),
            _sourceTile(
              icon: Icons.photo_library_rounded,
              title: 'Upload from gallery',
              subtitle: 'Pick an existing photo',
              onTap: () {
                Navigator.pop(ctx);
                _runInspection(context, ImageSource.gallery);
              },
            ),
          ],
        ),
      );
    },
  );
}

Widget _sourceTile({required IconData icon, required String title, required String subtitle, required VoidCallback onTap}) {
  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(16),
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.fieldFill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.edge),
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: AppColors.primaryMuted, borderRadius: BorderRadius.circular(13)),
            child: Icon(icon, size: 23, color: AppColors.primaryHover),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.ink)),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(fontSize: 12, color: AppColors.inkMuted, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: AppColors.hairline),
        ],
      ),
    ),
  );
}

/// Pick an image, analyze it, then show an error popup or the result page.
Future<void> _runInspection(BuildContext context, ImageSource source) async {
  Uint8List bytes;
  try {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: source, imageQuality: 70, maxWidth: 1280);
    if (file == null) return; // user cancelled
    bytes = await file.readAsBytes();
  } catch (_) {
    if (context.mounted) _showErrorDialog(context, 'Could not open the image. Please try again.');
    return;
  }

  if (!context.mounted) return;
  _showLoadingDialog(context);

  DamageReport report;
  try {
    // Camera button → Python YOLO vision API (folder `python-vision-api`).
    report = await VisionApiService.analyze(bytes);
  } on AiException catch (e) {
    if (context.mounted) Navigator.pop(context); // close loading
    if (context.mounted) _showErrorDialog(context, e.message);
    return;
  } catch (_) {
    if (context.mounted) Navigator.pop(context);
    if (context.mounted) _showErrorDialog(context, 'Could not analyze the photo. Please try again.');
    return;
  }

  if (!context.mounted) return;
  Navigator.pop(context); // close loading

  // Unrelated image (not a tire or brake pad) → error popup, not the result page.
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
    MaterialPageRoute(builder: (_) => InspectionResultScreen(imageBytes: bytes, report: report)),
  );
}

void _showLoadingDialog(BuildContext context) {
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
            Text('Analyzing photo…', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.ink)),
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
            width: 40, height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: AppColors.dangerBg, borderRadius: BorderRadius.circular(12)),
            child: Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 23),
          ),
          const SizedBox(width: 12),
          Text("Can't inspect", style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.ink)),
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
