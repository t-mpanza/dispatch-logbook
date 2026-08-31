import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/glass_decorations.dart';
import '../../core/utils/haptics.dart';
import '../../core/utils/id_generator.dart';
import '../../data/models/attachment.dart';
import '../../data/models/trip.dart';
import '../../data/services/camera_service.dart';

class CounterPanel extends StatefulWidget {
  final List<Trip> trips;
  final Function(List<Trip>) onChange;
  final Function(Attachment)? onAttachment;

  const CounterPanel({
    super.key,
    required this.trips,
    required this.onChange,
    this.onAttachment,
  });

  @override
  State<CounterPanel> createState() => _CounterPanelState();
}

class _CounterPanelState extends State<CounterPanel> {
  int _tabIndex = 0; // 0 = Scanned, 1 = Manual
  int _count = 0;
  int _manualCount = 1;
  final TextEditingController _slipController = TextEditingController();
  final TextEditingController _numberController = TextEditingController();

  Timer? _repeatTimer;
  Timer? _repeatInterval;

  static const List<int> _quickAdds = [2, 4, 8, 10];

  @override
  void initState() {
    super.initState();
    _updateDisplay();
  }

  void _updateDisplay() {
    final val = _tabIndex == 0 ? _count : _manualCount;
    _numberController.text = val > 0 ? '$val' : (_tabIndex == 0 ? '0' : '1');
  }

  void _stopRepeat() {
    _repeatTimer?.cancel();
    _repeatTimer = null;
    _repeatInterval?.cancel();
    _repeatInterval = null;
  }

  void _startRepeat(VoidCallback action) {
    _stopRepeat();
    AppHaptics.light();
    action();

    _repeatTimer = Timer(const Duration(milliseconds: 280), () {
      _repeatInterval = Timer.periodic(const Duration(milliseconds: 90), (_) {
        AppHaptics.light();
        action();
      });
    });
  }

  void _logScanned() {
    if (_count <= 0) return;
    AppHaptics.success();
    final newTrip = Trip(
      id: IdGenerator.generate(),
      count: _count,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    widget.onChange([...widget.trips, newTrip]);
    setState(() {
      _count = 0;
      _updateDisplay();
    });
  }

  void _logManual({String? noteOverride}) {
    if (_manualCount <= 0) return;
    AppHaptics.success();
    final slip = _slipController.text.trim();
    final note = noteOverride ?? (slip.isNotEmpty ? 'slip:text:$slip' : null);

    final newTrip = Trip(
      id: IdGenerator.generate(),
      count: 0,
      rejected: _manualCount,
      note: note,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    widget.onChange([...widget.trips, newTrip]);
    setState(() {
      _manualCount = 1;
      _slipController.clear();
      _updateDisplay();
    });
  }

  Future<void> _handleCaptureSlipPhoto() async {
    AppHaptics.light();
    final att = await CameraService.capturePhoto();
    if (att != null) {
      if (widget.onAttachment != null) {
        widget.onAttachment!(att);
      }
      _logManual(noteOverride: 'slip:photo:${att.id}');
    }
  }

  @override
  void dispose() {
    _stopRepeat();
    _slipController.dispose();
    _numberController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canLog = _tabIndex == 0 ? _count > 0 : _manualCount > 0;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: GlassDecorations.glassElevated(borderRadius: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Segmented Tabs
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildSegmentButton(
                    title: 'Scanned',
                    isActive: _tabIndex == 0,
                    onTap: () {
                      AppHaptics.light();
                      setState(() {
                        _tabIndex = 0;
                        _updateDisplay();
                      });
                    },
                  ),
                ),
                Expanded(
                  child: _buildSegmentButton(
                    title: 'Manual (No-NFC)',
                    isActive: _tabIndex == 1,
                    onTap: () {
                      AppHaptics.light();
                      setState(() {
                        _tabIndex = 1;
                        _updateDisplay();
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Steppers & Numeric Row
          Row(
            children: [
              // Stepper Minus
              GestureDetector(
                onTapDown: (_) => _startRepeat(() {
                  setState(() {
                    if (_tabIndex == 0) {
                      _count = (_count - 1).clamp(0, 9999);
                    } else {
                      _manualCount = (_manualCount - 1).clamp(1, 9999);
                    }
                    _updateDisplay();
                  });
                }),
                onTapUp: (_) => _stopRepeat(),
                onTapCancel: _stopRepeat,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.glassSurfaceElevated,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.glassBorder),
                  ),
                  child: const Center(
                    child: Icon(Icons.remove_rounded, color: AppColors.textPrimary, size: 20),
                  ),
                ),
              ),
              const SizedBox(width: 6),

              // Number Display / Input
              SizedBox(
                width: 52,
                height: 40,
                child: TextField(
                  controller: _numberController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                    fontFamily: 'monospace',
                  ),
                  decoration: InputDecoration(
                    contentPadding: EdgeInsets.zero,
                    filled: true,
                    fillColor: Colors.black.withValues(alpha: 0.4),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.glassBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.primaryGlow, width: 1.5),
                    ),
                  ),
                  onChanged: (val) {
                    final n = int.tryParse(val) ?? 0;
                    if (_tabIndex == 0) {
                      _count = n.clamp(0, 9999);
                    } else {
                      _manualCount = n.clamp(1, 9999);
                    }
                  },
                ),
              ),
              const SizedBox(width: 6),

              // Stepper Plus
              GestureDetector(
                onTapDown: (_) => _startRepeat(() {
                  setState(() {
                    if (_tabIndex == 0) {
                      _count += 1;
                    } else {
                      _manualCount += 1;
                    }
                    _updateDisplay();
                  });
                }),
                onTapUp: (_) => _stopRepeat(),
                onTapCancel: _stopRepeat,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.glassSurfaceElevated,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.glassBorder),
                  ),
                  child: const Center(
                    child: Icon(Icons.add_rounded, color: AppColors.textPrimary, size: 20),
                  ),
                ),
              ),
              const SizedBox(width: 6),

              // Quick Add Buttons or Slip Input
              if (_tabIndex == 0)
                Expanded(
                  child: Row(
                    children: [
                      for (final n in _quickAdds)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: GestureDetector(
                              onTapDown: (_) => _startRepeat(() {
                                setState(() {
                                  _count += n;
                                  _updateDisplay();
                                });
                              }),
                              onTapUp: (_) => _stopRepeat(),
                              onTapCancel: _stopRepeat,
                              child: Container(
                                height: 40,
                                decoration: BoxDecoration(
                                  color: AppColors.glassSurfaceElevated,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: AppColors.glassBorder),
                                ),
                                child: Center(
                                  child: Text(
                                    '+$n',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900,
                                      color: AppColors.primaryGlow,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                )
              else
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 40,
                          child: TextField(
                            controller: _slipController,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textPrimary,
                              fontFamily: 'monospace',
                            ),
                            decoration: InputDecoration(
                              hintText: 'Slip #',
                              hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                              filled: true,
                              fillColor: Colors.black.withValues(alpha: 0.4),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(color: AppColors.glassBorder),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: _handleCaptureSlipPhoto,
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.warning.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
                          ),
                          child: const Center(
                            child: Icon(Icons.camera_alt_rounded, color: AppColors.warning, size: 18),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),

          // Log Action Button
          SizedBox(
            width: double.infinity,
            height: 42,
            child: ElevatedButton(
              onPressed: canLog ? (_tabIndex == 0 ? _logScanned : () => _logManual()) : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: _tabIndex == 0 ? AppColors.primary : AppColors.warning,
                disabledBackgroundColor: Colors.white.withValues(alpha: 0.05),
                foregroundColor: Colors.white,
                disabledForegroundColor: AppColors.textMuted,
                elevation: canLog ? 6 : 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_rounded, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    _tabIndex == 0
                        ? 'LOG ${_count > 0 ? "$_count " : ""}SCANNED'
                        : 'LOG $_manualCount MANUAL',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
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

  Widget _buildSegmentButton({
    required String title,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? AppColors.glassSurfaceElevated : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive ? Colors.white.withValues(alpha: 0.2) : Colors.transparent,
          ),
        ),
        child: Center(
          child: Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 9,
              fontWeight: isActive ? FontWeight.w900 : FontWeight.w600,
              color: isActive ? AppColors.textPrimary : AppColors.textMuted,
              letterSpacing: 0.6,
            ),
          ),
        ),
      ),
    );
  }
}
