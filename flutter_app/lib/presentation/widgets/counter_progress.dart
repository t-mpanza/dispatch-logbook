import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/glass_decorations.dart';
import '../../core/utils/haptics.dart';

class CounterProgress extends StatelessWidget {
  final int total;
  final int tripCount;
  final int? expectedTotal;
  final String? truckReg;
  final String? driverName;
  final String? tripTitle;
  final Function(int?) onSetExpected;
  final Function(String? reg, String? driver, int? target)? onUpdateTruckDetails;

  const CounterProgress({
    super.key,
    required this.total,
    required this.tripCount,
    this.expectedTotal,
    this.truckReg,
    this.driverName,
    this.tripTitle,
    required this.onSetExpected,
    this.onUpdateTruckDetails,
  });

  void _showEditDetailsDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _TruckTargetBottomSheet(
        initialReg: truckReg,
        initialDriver: driverName,
        initialTarget: expectedTotal,
        onSave: (reg, driver, target) {
          if (onUpdateTruckDetails != null) {
            onUpdateTruckDetails!(reg, driver, target);
          } else {
            onSetExpected(target);
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLight = AppColors.isLight(context);
    final hasTarget = expectedTotal != null && expectedTotal! > 0;
    final remaining = hasTarget ? expectedTotal! - total : 0;
    final isOver = hasTarget && total > expectedTotal!;
    final isComplete = hasTarget && total == expectedTotal!;
    final pct = hasTarget && expectedTotal! > 0 ? (total / expectedTotal!).clamp(0.0, 1.0) : 0.0;
    final pctText = hasTarget ? '${(pct * 100).toStringAsFixed(0)}%' : null;

    final hasTruck = (truckReg != null && truckReg!.isNotEmpty) || (driverName != null && driverName!.isNotEmpty);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: GlassDecorations.glassElevated(context: context, borderRadius: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Compact Header Row: Truck Assignment & Target / Status Badge
          Row(
            children: [
              // Truck Info Clickable Pill
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    AppHaptics.light();
                    _showEditDetailsDialog(context);
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: isLight ? 0.12 : 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(
                          Icons.local_shipping_rounded,
                          size: 12,
                          color: isLight ? AppColors.primary : AppColors.primaryGlow,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          hasTruck
                              ? '${tripTitle != null && tripTitle!.isNotEmpty ? "$tripTitle • " : ""}${truckReg?.isNotEmpty == true ? truckReg : "NO REG"}${driverName?.isNotEmpty == true ? " ($driverName)" : ""}'
                              : (tripTitle ?? 'Tap to assign truck'),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.dynamicTextPrimary(context),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.edit_outlined, size: 12, color: AppColors.dynamicTextMuted(context)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Status / Target Action Pill
              GestureDetector(
                onTap: () {
                  AppHaptics.light();
                  _showEditDetailsDialog(context);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isComplete
                        ? AppColors.success.withValues(alpha: 0.15)
                        : (isOver
                            ? AppColors.warning.withValues(alpha: 0.15)
                            : (hasTarget
                                ? AppColors.primary.withValues(alpha: isLight ? 0.12 : 0.15)
                                : (isLight ? const Color(0xFFF1F5F9) : AppColors.glassSurface))),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isComplete
                          ? AppColors.success.withValues(alpha: 0.4)
                          : (isOver
                              ? AppColors.warning.withValues(alpha: 0.4)
                              : (hasTarget
                                  ? (isLight ? AppColors.primary.withValues(alpha: 0.4) : AppColors.primaryGlow.withValues(alpha: 0.4))
                                  : (isLight ? const Color(0xFFCBD5E1) : AppColors.glassBorder))),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isComplete
                            ? Icons.check_circle_rounded
                            : (isOver
                                ? Icons.warning_amber_rounded
                                : (hasTarget ? Icons.hourglass_bottom_rounded : Icons.track_changes)),
                        size: 11,
                        color: isComplete
                            ? AppColors.success
                            : (isOver
                                ? AppColors.warning
                                : (hasTarget
                                    ? (isLight ? AppColors.primary : AppColors.primaryGlow)
                                    : AppColors.dynamicTextMuted(context))),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isComplete
                            ? 'LOAD COMPLETE'
                            : (isOver
                                ? '+$remaining OVER'
                                : (hasTarget ? '$remaining LEFT' : '+ Set Target')),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: isComplete
                              ? AppColors.success
                              : (isOver
                                  ? AppColors.warning
                                  : (hasTarget
                                      ? (isLight ? AppColors.primary : AppColors.primaryGlow)
                                      : AppColors.dynamicTextMuted(context))),
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Counts Row: Tyres Count + Target Metric + Percentage
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '$total',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: isLight ? AppColors.primary : AppColors.primaryGlow,
                  fontFamily: 'monospace',
                  letterSpacing: -0.5,
                  height: 1.0,
                ),
              ),
              if (hasTarget)
                Text(
                  ' / $expectedTotal',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.dynamicTextMuted(context),
                    fontFamily: 'monospace',
                  ),
                ),
              const SizedBox(width: 4),
              Text(
                'tyres',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppColors.dynamicTextMuted(context),
                ),
              ),
              const Spacer(),
              if (hasTarget && pctText != null)
                Text(
                  '$pctText loaded',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isComplete
                        ? AppColors.success
                        : (isOver ? AppColors.warning : AppColors.dynamicTextSecondary(context)),
                    fontFamily: 'monospace',
                  ),
                )
              else
                Text(
                  '$tripCount ${tripCount == 1 ? 'batch' : 'batches'}',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.dynamicTextMuted(context),
                    fontFamily: 'monospace',
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),

          // Mini High-Precision Gradient Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: hasTarget ? pct : 0.0,
              minHeight: 3.5,
              backgroundColor: isLight ? const Color(0xFFE2E8F0) : Colors.white.withValues(alpha: 0.06),
              valueColor: AlwaysStoppedAnimation<Color>(
                isComplete
                    ? AppColors.success
                    : (isOver ? AppColors.warning : (isLight ? AppColors.primary : AppColors.primaryGlow)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TruckTargetBottomSheet extends StatefulWidget {
  final String? initialReg;
  final String? initialDriver;
  final int? initialTarget;
  final Function(String? reg, String? driver, int? target) onSave;

  const _TruckTargetBottomSheet({
    this.initialReg,
    this.initialDriver,
    this.initialTarget,
    required this.onSave,
  });

  @override
  State<_TruckTargetBottomSheet> createState() => _TruckTargetBottomSheetState();
}

class _TruckTargetBottomSheetState extends State<_TruckTargetBottomSheet> {
  late TextEditingController _regCtrl;
  late TextEditingController _driverCtrl;
  late TextEditingController _targetCtrl;
  late int _targetValue;

  Timer? _repeatTimer;
  Timer? _repeatInterval;

  static const List<int> _quickIncrements = [1, 5, 10, 20, 50];
  static const List<int> _capacityPresets = [60, 100, 150, 200, 250, 300, 400, 500];

  @override
  void initState() {
    super.initState();
    _regCtrl = TextEditingController(text: widget.initialReg ?? '');
    _driverCtrl = TextEditingController(text: widget.initialDriver ?? '');
    _targetValue = widget.initialTarget ?? 0;
    _targetCtrl = TextEditingController(text: _targetValue > 0 ? '$_targetValue' : '');
  }

  void _stopRepeat() {
    _repeatTimer?.cancel();
    _repeatInterval?.cancel();
  }

  void _triggerAutoSave() {
    final reg = _regCtrl.text.trim().toUpperCase();
    final driver = _driverCtrl.text.trim();
    final target = _targetValue > 0 ? _targetValue : null;
    widget.onSave(reg.isNotEmpty ? reg : null, driver.isNotEmpty ? driver : null, target);
  }

  void _startRepeat(VoidCallback action) {
    _stopRepeat();
    AppHaptics.light();
    action();

    _repeatTimer = Timer(const Duration(milliseconds: 260), () {
      _repeatInterval = Timer.periodic(const Duration(milliseconds: 75), (_) {
        AppHaptics.light();
        action();
      });
    });
  }

  void _setTarget(int val) {
    setState(() {
      _targetValue = val.clamp(0, 9999);
      _targetCtrl.text = _targetValue > 0 ? '$_targetValue' : '';
    });
    _triggerAutoSave();
  }

  void _incrementTarget(int delta) {
    setState(() {
      _targetValue = (_targetValue + delta).clamp(0, 9999);
      _targetCtrl.text = _targetValue > 0 ? '$_targetValue' : '';
    });
    _triggerAutoSave();
  }

  @override
  void dispose() {
    _stopRepeat();
    _regCtrl.dispose();
    _driverCtrl.dispose();
    _targetCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLight = AppColors.isLight(context);

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: BoxDecoration(
        color: isLight ? Colors.white : AppColors.backgroundSecondary,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag Handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: isLight ? const Color(0xFFCBD5E1) : Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Title
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Truck & Target Settings',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: AppColors.dynamicTextPrimary(context),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded, color: AppColors.dynamicTextMuted(context)),
                  onPressed: () {
                    _triggerAutoSave();
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Reg & Driver Inputs
            Row(
              children: [
                Expanded(
                  child: _buildInput(
                    label: 'REG PLATE',
                    controller: _regCtrl,
                    hint: 'e.g. MN27PT',
                    isMonospace: true,
                    isCaps: true,
                    isLight: isLight,
                    onChanged: (_) => _triggerAutoSave(),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildInput(
                    label: 'DRIVER NAME',
                    controller: _driverCtrl,
                    hint: 'e.g. Stephen',
                    isLight: isLight,
                    onChanged: (_) => _triggerAutoSave(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Target Tyres with Long-Press Stepper
            Text(
              'TARGET TYRES (HOLD TO AUTO-INCREMENT)',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: AppColors.dynamicTextMuted(context),
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                // Stepper Minus (Hold to repeat)
                GestureDetector(
                  onTapDown: (_) => _startRepeat(() => _incrementTarget(-1)),
                  onTapUp: (_) => _stopRepeat(),
                  onTapCancel: _stopRepeat,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isLight ? const Color(0xFFF1F5F9) : AppColors.glassSurfaceElevated,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isLight ? const Color(0xFFCBD5E1) : AppColors.glassBorder,
                      ),
                    ),
                    child: Center(
                      child: Icon(Icons.remove_rounded, color: AppColors.dynamicTextPrimary(context), size: 20),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Number Input Field
                Expanded(
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: isLight ? const Color(0xFFF8FAFC) : Colors.black.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isLight ? const Color(0xFFCBD5E1) : AppColors.glassBorder,
                      ),
                    ),
                    child: TextField(
                      controller: _targetCtrl,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: isLight ? AppColors.primary : AppColors.primaryGlow,
                        fontFamily: 'monospace',
                      ),
                      decoration: InputDecoration(
                        hintText: '0',
                        hintStyle: TextStyle(color: AppColors.dynamicTextMuted(context), fontSize: 16),
                        contentPadding: EdgeInsets.zero,
                        border: InputBorder.none,
                      ),
                      onChanged: (val) {
                        final n = int.tryParse(val) ?? 0;
                        setState(() => _targetValue = n.clamp(0, 9999));
                        _triggerAutoSave();
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Stepper Plus (Hold to repeat)
                GestureDetector(
                  onTapDown: (_) => _startRepeat(() => _incrementTarget(1)),
                  onTapUp: (_) => _stopRepeat(),
                  onTapCancel: _stopRepeat,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isLight ? const Color(0xFFF1F5F9) : AppColors.glassSurfaceElevated,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isLight ? const Color(0xFFCBD5E1) : AppColors.glassBorder,
                      ),
                    ),
                    child: Center(
                      child: Icon(Icons.add_rounded, color: AppColors.dynamicTextPrimary(context), size: 20),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Quick Increments Row (Hold to auto-repeat)
            Text(
              'INCREMENT BY (TAP OR HOLD):',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: AppColors.dynamicTextMuted(context),
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: _quickIncrements.map((inc) {
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: GestureDetector(
                      onTapDown: (_) => _startRepeat(() => _incrementTarget(inc)),
                      onTapUp: (_) => _stopRepeat(),
                      onTapCancel: _stopRepeat,
                      child: Container(
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: isLight ? 0.1 : 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isLight ? AppColors.primary.withValues(alpha: 0.3) : AppColors.primaryGlow.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Center(
                          child: Text(
                            '+$inc',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: isLight ? AppColors.primary : AppColors.primaryGlow,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),

            // Truck Capacity Presets
            Text(
              'TRUCK CAPACITY PRESETS:',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: AppColors.dynamicTextMuted(context),
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _capacityPresets.map((qty) {
                final isSelected = _targetValue == qty;
                return GestureDetector(
                  onTap: () {
                    AppHaptics.light();
                    _setTarget(qty);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary.withValues(alpha: isLight ? 0.2 : 0.3)
                          : (isLight ? const Color(0xFFF1F5F9) : AppColors.glassSurfaceElevated),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected
                            ? (isLight ? AppColors.primary : AppColors.primaryGlow)
                            : (isLight ? const Color(0xFFCBD5E1) : AppColors.glassBorder),
                        width: isSelected ? 1.5 : 1.0,
                      ),
                    ),
                    child: Text(
                      '$qty',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isSelected
                            ? (isLight ? AppColors.primary : Colors.white)
                            : AppColors.dynamicTextSecondary(context),
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // Actions
            Row(
              children: [
                if (_targetValue > 0)
                  TextButton(
                    onPressed: () {
                      AppHaptics.light();
                      _setTarget(0);
                    },
                    child: const Text('Clear Target', style: TextStyle(color: AppColors.error, fontSize: 12)),
                  ),
                const Spacer(),
                ElevatedButton(
                  onPressed: () {
                    AppHaptics.success();
                    _triggerAutoSave();
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Save Details', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInput({
    required String label,
    required TextEditingController controller,
    required String hint,
    required bool isLight,
    bool isMonospace = false,
    bool isCaps = false,
    Function(String)? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w800,
            color: AppColors.dynamicTextMuted(context),
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: isLight ? const Color(0xFFF8FAFC) : Colors.black.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isLight ? const Color(0xFFCBD5E1) : AppColors.glassBorder,
            ),
          ),
          child: Center(
            child: TextField(
              controller: controller,
              textCapitalization: isCaps ? TextCapitalization.characters : TextCapitalization.words,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppColors.dynamicTextPrimary(context),
                fontFamily: isMonospace ? 'monospace' : null,
              ),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(color: AppColors.dynamicTextMuted(context), fontSize: 12),
                contentPadding: EdgeInsets.zero,
                border: InputBorder.none,
                isDense: true,
              ),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}
