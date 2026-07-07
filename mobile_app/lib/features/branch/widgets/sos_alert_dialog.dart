import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:audioplayers/audioplayers.dart';

/// Full-screen-feel emergency alert for an incoming, not-yet-accepted SOS.
/// Pulses, vibrates on a loop, and forces a deliberate action (no tap-outside).
Future<void> showSosAlert(
  BuildContext context,
  Map<String, dynamic> rescue, {
  required Future<bool> Function() onAccept,
  required VoidCallback onView,
  required VoidCallback onCall,
}) {
  return showDialog(
    context: context,
    barrierDismissible: false,
    barrierColor: const Color(0xCC4C0519), // deep red wash
    builder: (_) => _SosAlertDialog(
      rescue: rescue,
      onAccept: onAccept,
      onView: onView,
      onCall: onCall,
    ),
  );
}

class _SosAlertDialog extends StatefulWidget {
  final Map<String, dynamic> rescue;
  final Future<bool> Function() onAccept;
  final VoidCallback onView;
  final VoidCallback onCall;
  const _SosAlertDialog({
    required this.rescue,
    required this.onAccept,
    required this.onView,
    required this.onCall,
  });

  @override
  State<_SosAlertDialog> createState() => _SosAlertDialogState();
}

class _SosAlertDialogState extends State<_SosAlertDialog> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  Timer? _buzz;
  final AudioPlayer _siren = AudioPlayer();
  bool _accepting = false;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..repeat(reverse: true);
    // Buzz immediately, then keep buzzing like a siren until dismissed.
    HapticFeedback.heavyImpact();
    _buzz = Timer.periodic(const Duration(milliseconds: 900), (_) => HapticFeedback.heavyImpact());
    _startSiren();
  }

  Future<void> _startSiren() async {
    try {
      await _siren.setReleaseMode(ReleaseMode.loop);
      // Route through the ALARM stream so it's audible even with low media
      // volume or the ringer silenced — like a real emergency alert.
      await _siren.setAudioContext(AudioContext(
        android: const AudioContextAndroid(
          isSpeakerphoneOn: true,
          stayAwake: true,
          contentType: AndroidContentType.sonification,
          usageType: AndroidUsageType.alarm,
          audioFocus: AndroidAudioFocus.gainTransient,
        ),
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.playback,
          options: const {AVAudioSessionOptions.duckOthers},
        ),
      ));
      await _siren.setVolume(1.0);
      await _siren.play(AssetSource('sounds/sos_alarm.wav'));
    } catch (_) {/* audio is best-effort; the visual + haptics still alarm */}
  }

  @override
  void dispose() {
    _buzz?.cancel();
    _pulse.dispose();
    _siren.dispose();
    super.dispose();
  }

  // Silence the alarm (siren + haptics + pulse) once the case is handled.
  void _stopBuzz() {
    _buzz?.cancel();
    _pulse.stop();
    _siren.stop();
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.rescue;
    final customer = (r['customer'] as Map?) ?? const {};
    final vehicle = (r['vehicle'] as Map?) ?? const {};
    final name = customer['fullName'] ?? 'Anonymous rider';
    final issue = r['issueDescription'] ?? 'Emergency assistance requested';
    final plate = vehicle['licensePlate'] ?? '—';
    final bike = '${vehicle['brand'] ?? ''} ${vehicle['model'] ?? ''}'.trim();

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 40),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: const LinearGradient(
            colors: [Color(0xFFEF4444), Color(0xFFDC2626), Color(0xFFB91C1C)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(color: const Color(0xFFDC2626).withValues(alpha: 0.6), blurRadius: 50, offset: const Offset(0, 18)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 26),
            // Pulsing siren badge
            AnimatedBuilder(
              animation: _pulse,
              builder: (_, child) {
                final t = _pulse.value;
                return SizedBox(
                  width: 110, height: 110,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 70 + t * 40, height: 70 + t * 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.18 * (1 - t)),
                        ),
                      ),
                      child!,
                    ],
                  ),
                );
              },
              child: Container(
                width: 70, height: 70,
                alignment: Alignment.center,
                decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                child: const Icon(Icons.sos_rounded, color: Color(0xFFDC2626), size: 40),
              ),
            ),
            const SizedBox(height: 12),
            Text('EMERGENCY SOS', style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 1)),
            const SizedBox(height: 2),
            Text('A rider needs urgent rescue', style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 13, fontWeight: FontWeight.w500)),
            const SizedBox(height: 20),

            // Detail panel
            Container(
              margin: const EdgeInsets.fromLTRB(18, 0, 18, 18),
              padding: const EdgeInsets.all(16),
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.person_rounded, size: 20, color: Color(0xFFB91C1C)),
                      const SizedBox(width: 8),
                      Expanded(child: Text(name, style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w800, color: const Color(0xFF1C1917)))),
                      Text('#${r['id']}', style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFFB91C1C))),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFFECACA))),
                    child: Text('⚠️ $issue', style: const TextStyle(color: Color(0xFFB91C1C), fontWeight: FontWeight.w700, height: 1.3)),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.two_wheeler_rounded, size: 17, color: Color(0xFF78716C)),
                      const SizedBox(width: 8),
                      Expanded(child: Text(bike.isEmpty ? 'Vehicle on file' : bike, style: const TextStyle(color: Color(0xFF44403C), fontWeight: FontWeight.w600))),
                      Text(plate, style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF1C1917), letterSpacing: 0.5)),
                    ],
                  ),
                ],
              ),
            ),

            // Actions
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton.icon(
                      onPressed: _accepting
                          ? null
                          : () async {
                              setState(() => _accepting = true);
                              final ok = await widget.onAccept();
                              _stopBuzz();
                              if (context.mounted) Navigator.of(context).pop();
                              if (!ok && context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Could not accept the case. Please try again.')),
                                );
                              }
                            },
                      icon: _accepting
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.4, color: Color(0xFFDC2626)))
                          : const Icon(Icons.local_shipping_rounded),
                      label: Text(_accepting ? 'Dispatching…' : 'ACCEPT & DISPATCH', style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.3)),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFFB91C1C),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 46,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              _stopBuzz(); // silence the siren during the call
                              widget.onCall();
                            },
                            icon: const Icon(Icons.phone_rounded, size: 18),
                            label: const Text('Call'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: BorderSide(color: Colors.white.withValues(alpha: 0.7), width: 1.5),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: SizedBox(
                          height: 46,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              _stopBuzz();
                              Navigator.of(context).pop();
                              widget.onView();
                            },
                            icon: const Icon(Icons.open_in_new_rounded, size: 18),
                            label: const Text('View'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: BorderSide(color: Colors.white.withValues(alpha: 0.7), width: 1.5),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  TextButton(
                    onPressed: () {
                      _stopBuzz();
                      Navigator.of(context).pop();
                    },
                    child: Text('Dismiss', style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
