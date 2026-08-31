import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/haptics.dart';
import '../../core/utils/id_generator.dart';
import '../../data/models/loading_sheet_trip.dart';
import '../../data/models/preset.dart';

class TruckLoadDialog extends StatefulWidget {
  final LoadingSheetTrip? existingTrip;
  final String dayKey;
  final List<LoadingSheetTrip> existingTrips;
  final Function(LoadingSheetTrip) onSave;
  final VoidCallback? onDelete;

  const TruckLoadDialog({
    super.key,
    this.existingTrip,
    required this.dayKey,
    required this.existingTrips,
    required this.onSave,
    this.onDelete,
  });

  static Future<void> show(
    BuildContext context, {
    LoadingSheetTrip? existingTrip,
    required String dayKey,
    required List<LoadingSheetTrip> existingTrips,
    required Function(LoadingSheetTrip) onSave,
    VoidCallback? onDelete,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => TruckLoadDialog(
        existingTrip: existingTrip,
        dayKey: dayKey,
        existingTrips: existingTrips,
        onSave: onSave,
        onDelete: onDelete,
      ),
    );
  }

  @override
  State<TruckLoadDialog> createState() => _TruckLoadDialogState();
}

class _TruckLoadDialogState extends State<TruckLoadDialog> {
  late PresetKey _selectedPreset;
  late TextEditingController _tripIdController;
  late TextEditingController _regController;
  late TextEditingController _driverController;
  late TextEditingController _startController;
  late TextEditingController _finishController;
  late TextEditingController _targetController;
  int _quantityLoaded = 0;
  int _targetQuantity = 0;

  Timer? _repeatTimer;
  Timer? _repeatInterval;

  static const List<int> _quickIncrements = [1, 5, 10, 20, 50];

  @override
  void initState() {
    super.initState();
    final isEdit = widget.existingTrip != null;

    if (isEdit) {
      final t = widget.existingTrip!;
      _selectedPreset = t.presetKey ?? PresetKey.CUSTOM;
      _tripIdController = TextEditingController(text: t.tripId);
      _regController = TextEditingController(text: t.reg);
      _driverController = TextEditingController(text: t.driverName);
      _startController = TextEditingController(text: AppFormatters.formatTimeHHmm(t.startTime));
      _finishController = TextEditingController(text: AppFormatters.formatTimeHHmm(t.finishTime));
      _targetQuantity = t.targetQuantity ?? 0;
      _targetController = TextEditingController(
          text: _targetQuantity > 0 ? '$_targetQuantity' : '');
      _quantityLoaded = t.quantityLoaded;
    } else {
      _selectedPreset = PresetKey.STOCKS;
      final fill = PresetEngine.getPresetFill(
        PresetKey.STOCKS,
        existingTripIds: widget.existingTrips.map((t) => t.tripId).toList(),
      );
      _tripIdController = TextEditingController(text: fill.tripId);
      _regController = TextEditingController(text: fill.reg ?? '');
      _driverController = TextEditingController(text: fill.driverName ?? '');
      _startController = TextEditingController();
      _finishController = TextEditingController();
      _targetQuantity = 0;
      _targetController = TextEditingController();
      _quantityLoaded = 0;
    }
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

    _repeatTimer = Timer(const Duration(milliseconds: 260), () {
      _repeatInterval = Timer.periodic(const Duration(milliseconds: 75), (_) {
        AppHaptics.light();
        action();
      });
    });
  }

  void _incrementLoaded(int delta) {
    setState(() {
      _quantityLoaded = (_quantityLoaded + delta).clamp(0, 9999);
    });
  }

  void _incrementTarget(int delta) {
    setState(() {
      _targetQuantity = (_targetQuantity + delta).clamp(0, 9999);
      _targetController.text = _targetQuantity > 0 ? '$_targetQuantity' : '';
    });
  }

  void _onPresetChanged(PresetKey key) {
    AppHaptics.light();
    setState(() {
      _selectedPreset = key;
      final fill = PresetEngine.getPresetFill(
        key,
        existingTripIds: widget.existingTrips.map((t) => t.tripId).toList(),
      );
      _tripIdController.text = fill.tripId;
      if (fill.reg != null) _regController.text = fill.reg!;
      if (fill.driverName != null) _driverController.text = fill.driverName!;
    });
  }

  void _handleSave() {
    AppHaptics.success();
    final now = DateTime.now().millisecondsSinceEpoch;
    final baseDateMs = widget.existingTrip?.createdAt ??
        (DateTime.tryParse(widget.dayKey)?.millisecondsSinceEpoch ?? now);

    final startMs = AppFormatters.timeStringToMs(_startController.text, baseDateMs);
    final finishMs = AppFormatters.timeStringToMs(_finishController.text, baseDateMs);

    int? duration;
    if (startMs != null && finishMs != null) {
      final diff = finishMs - startMs;
      duration = diff > 0 ? (diff / (1000 * 60)).round() : 1;
    }

    final targetQty = _targetQuantity > 0 ? _targetQuantity : int.tryParse(_targetController.text.trim());

    final trip = LoadingSheetTrip(
      id: widget.existingTrip?.id ?? IdGenerator.generate(),
      entryId: widget.existingTrip?.entryId,
      reg: _regController.text.trim().toUpperCase(),
      driverName: _driverController.text.trim(),
      tripId: _tripIdController.text.trim().isNotEmpty
          ? _tripIdController.text.trim()
          : _selectedPreset.name,
      presetKey: _selectedPreset,
      startTime: startMs,
      finishTime: finishMs,
      durationMinutes: duration,
      quantityLoaded: _quantityLoaded,
      targetQuantity: targetQty,
      isManual: widget.existingTrip?.isManual ?? false,
      createdAt: widget.existingTrip?.createdAt ?? startMs ?? now,
    );

    widget.onSave(trip);
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _stopRepeat();
    _tripIdController.dispose();
    _regController.dispose();
    _driverController.dispose();
    _startController.dispose();
    _finishController.dispose();
    _targetController.dispose();
    super.dispose();
  }

  Color _getPresetColor(PresetKey key) {
    switch (key) {
      case PresetKey.DBN:
        return AppColors.presetDbn;
      case PresetKey.NLS:
        return AppColors.presetNls;
      case PresetKey.BLOEM:
        return AppColors.presetBloem;
      case PresetKey.PLK:
        return AppColors.presetPlk;
      case PresetKey.STOCKS:
        return AppColors.presetStocks;
      case PresetKey.NLH:
        return AppColors.presetNlh;
      case PresetKey.TIREPOINT:
        return AppColors.presetTirepoint;
      case PresetKey.CUSTOM:
        return AppColors.primaryGlow;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existingTrip != null;
    final target = _targetQuantity > 0 ? _targetQuantity : (int.tryParse(_targetController.text.trim()) ?? 0);
    final remaining = target > 0 ? target - _quantityLoaded : 0;
    final isOver = target > 0 && _quantityLoaded > target;
    final isDone = target > 0 && _quantityLoaded == target;

    final isLight = AppColors.isLight(context);

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
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
            const SizedBox(height: 16),

            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isEdit ? 'Edit Truck Load' : 'Add Truck Load',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: AppColors.dynamicTextPrimary(context),
                    letterSpacing: -0.3,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded, color: AppColors.dynamicTextMuted(context)),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Route Preset Chips
            const Text(
              'ROUTE PRESET',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textMuted, letterSpacing: 1.0),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: PresetEngine.loadingPresets.map((preset) {
                final isSelected = _selectedPreset == preset.key;
                final color = _getPresetColor(preset.key);

                return GestureDetector(
                  onTap: () => _onPresetChanged(preset.key),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected ? color.withValues(alpha: 0.25) : AppColors.glassSurface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected ? color : Colors.white.withValues(alpha: 0.08),
                        width: isSelected ? 1.5 : 1.0,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          preset.label,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                            color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Trip ID & Vehicle Reg
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    label: 'TRIP / ROUTE NAME',
                    controller: _tripIdController,
                    hint: 'e.g. STOCKS 1',
                    textCapitalization: TextCapitalization.characters,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildTextField(
                    label: 'REG PLATE',
                    controller: _regController,
                    hint: 'e.g. MN05XNGP',
                    textCapitalization: TextCapitalization.characters,
                    isMonospace: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Driver Name
            _buildTextField(
              label: 'DRIVER NAME',
              controller: _driverController,
              hint: 'e.g. Neil',
            ),
            const SizedBox(height: 14),

            // Quantities: Target vs Loaded Steppers
            Row(
              children: [
                // Target Qty Stepper
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'TARGET TYRES',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textMuted, letterSpacing: 1.0),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.glassBorder),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            GestureDetector(
                              onTapDown: (_) => _startRepeat(() => _incrementTarget(-1)),
                              onTapUp: (_) => _stopRepeat(),
                              onTapCancel: _stopRepeat,
                              child: const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 8),
                                child: Icon(Icons.remove_rounded, size: 18, color: AppColors.textPrimary),
                              ),
                            ),
                            Expanded(
                              child: TextField(
                                controller: _targetController,
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                onChanged: (val) {
                                  final n = int.tryParse(val) ?? 0;
                                  setState(() => _targetQuantity = n.clamp(0, 9999));
                                },
                                style: const TextStyle(
                                  fontSize: 15,
                                  color: AppColors.primaryGlow,
                                  fontWeight: FontWeight.w900,
                                  fontFamily: 'monospace',
                                ),
                                decoration: const InputDecoration(
                                  hintText: '0',
                                  hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 13),
                                  contentPadding: EdgeInsets.zero,
                                  border: InputBorder.none,
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTapDown: (_) => _startRepeat(() => _incrementTarget(1)),
                              onTapUp: (_) => _stopRepeat(),
                              onTapCancel: _stopRepeat,
                              child: const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 8),
                                child: Icon(Icons.add_rounded, size: 18, color: AppColors.textPrimary),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),

                // Loaded Qty Stepper
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'LOADED TYRES',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textMuted, letterSpacing: 1.0),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.glassBorder),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            GestureDetector(
                              onTapDown: (_) => _startRepeat(() => _incrementLoaded(-1)),
                              onTapUp: (_) => _stopRepeat(),
                              onTapCancel: _stopRepeat,
                              child: const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 8),
                                child: Icon(Icons.remove_rounded, size: 18, color: AppColors.textPrimary),
                              ),
                            ),
                            Text(
                              '$_quantityLoaded',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: AppColors.primaryGlow,
                                fontFamily: 'monospace',
                              ),
                            ),
                            GestureDetector(
                              onTapDown: (_) => _startRepeat(() => _incrementLoaded(1)),
                              onTapUp: (_) => _stopRepeat(),
                              onTapCancel: _stopRepeat,
                              child: const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 8),
                                child: Icon(Icons.add_rounded, size: 18, color: AppColors.textPrimary),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Quick Target Increment Chips
            Row(
              children: [
                const Text('Target +: ', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textMuted)),
                const SizedBox(width: 4),
                ..._quickIncrements.map((inc) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: GestureDetector(
                      onTapDown: (_) => _startRepeat(() => _incrementTarget(inc)),
                      onTapUp: (_) => _stopRepeat(),
                      onTapCancel: _stopRepeat,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.primaryGlow.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          '+$inc',
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primaryGlow, fontFamily: 'monospace'),
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),

            // Target Progress Pill (if target is entered)
            if (target > 0) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isDone
                      ? AppColors.success.withValues(alpha: 0.15)
                      : (isOver
                          ? AppColors.warning.withValues(alpha: 0.15)
                          : AppColors.primary.withValues(alpha: 0.15)),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDone
                        ? AppColors.success.withValues(alpha: 0.4)
                        : (isOver
                            ? AppColors.warning.withValues(alpha: 0.4)
                            : AppColors.primaryGlow.withValues(alpha: 0.4)),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isDone
                          ? Icons.check_circle_rounded
                          : (isOver ? Icons.warning_amber_rounded : Icons.hourglass_bottom_rounded),
                      size: 14,
                      color: isDone ? AppColors.success : (isOver ? AppColors.warning : AppColors.primaryGlow),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isDone
                          ? 'Target reached! (100% loaded)'
                          : (isOver ? '+${_quantityLoaded - target} tyres over target!' : '$remaining tyres left to load'),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isDone ? AppColors.success : (isOver ? AppColors.warning : AppColors.primaryGlow),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),

            // Start & Finish Times
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    label: 'START TIME',
                    controller: _startController,
                    hint: 'HH:mm (e.g. 08:30)',
                    isMonospace: true,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildTextField(
                    label: 'FINISH TIME',
                    controller: _finishController,
                    hint: 'HH:mm (e.g. 09:15)',
                    isMonospace: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Action Buttons
            Row(
              children: [
                if (isEdit && widget.onDelete != null) ...[
                  TextButton.icon(
                    onPressed: () {
                      AppHaptics.error();
                      widget.onDelete!();
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 18),
                    label: const Text('Delete', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
                  ),
                  const Spacer(),
                ] else
                  const Spacer(),

                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _handleSave,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(
                    isEdit ? 'Save Changes' : 'Add Truck Load',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required String hint,
    TextCapitalization textCapitalization = TextCapitalization.none,
    bool isMonospace = false,
  }) {
    final isLight = AppColors.isLight(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.dynamicTextMuted(context), letterSpacing: 1.0),
        ),
        const SizedBox(height: 4),
        Container(
          height: 44,
          decoration: BoxDecoration(
            color: isLight ? const Color(0xFFF8FAFC) : Colors.black.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isLight ? const Color(0xFFCBD5E1) : AppColors.glassBorder),
          ),
          child: TextField(
            controller: controller,
            textCapitalization: textCapitalization,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.dynamicTextPrimary(context),
              fontFamily: isMonospace ? 'monospace' : null,
              fontWeight: isMonospace ? FontWeight.bold : FontWeight.w500,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: AppColors.dynamicTextMuted(context), fontSize: 11),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              border: InputBorder.none,
            ),
          ),
        ),
      ],
    );
  }
}
