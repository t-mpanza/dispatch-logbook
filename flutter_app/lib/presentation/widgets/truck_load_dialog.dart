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
  int _quantityLoaded = 0;

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
      _quantityLoaded = 0;
    }
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
      isManual: widget.existingTrip?.isManual ?? false,
      createdAt: widget.existingTrip?.createdAt ?? startMs ?? now,
    );

    widget.onSave(trip);
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _tripIdController.dispose();
    _regController.dispose();
    _driverController.dispose();
    _startController.dispose();
    _finishController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existingTrip != null;

    return Container(
      padding: EdgeInsets.only(
        top: 16,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Grabber handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.local_shipping_rounded, color: AppColors.primaryGlow, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEdit ? 'Edit Truck Load' : 'Add Truck Load',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                        ),
                        Text(
                          widget.dayKey,
                          style: const TextStyle(fontSize: 11, color: AppColors.textMuted, fontFamily: 'monospace'),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: AppColors.textMuted),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Preset Selector Grid
            const Text(
              'PRESET / DESTINATION',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textMuted, letterSpacing: 1.0),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final p in PresetEngine.loadingPresets)
                  GestureDetector(
                    onTap: () => _onPresetChanged(p.key),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: _selectedPreset == p.key
                            ? AppColors.primary
                            : AppColors.glassSurfaceElevated,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _selectedPreset == p.key
                              ? AppColors.primaryGlow
                              : AppColors.glassBorderLight,
                        ),
                      ),
                      child: Text(
                        p.label.replaceAll(' [i]', ''),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: _selectedPreset == p.key ? FontWeight.w900 : FontWeight.w600,
                          color: _selectedPreset == p.key ? Colors.white : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),

            // Trip ID & Reg
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    label: 'TRIP ID',
                    controller: _tripIdController,
                    hint: 'e.g. STOCKS 1',
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

            // Driver & Quantity
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    label: 'DRIVER NAME',
                    controller: _driverController,
                    hint: 'e.g. Neil',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'TYRES LOADED',
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
                            IconButton(
                              icon: const Icon(Icons.remove, size: 16, color: AppColors.textPrimary),
                              onPressed: () {
                                AppHaptics.light();
                                setState(() => _quantityLoaded = (_quantityLoaded - 1).clamp(0, 9999));
                              },
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
                            IconButton(
                              icon: const Icon(Icons.add, size: 16, color: AppColors.textPrimary),
                              onPressed: () {
                                AppHaptics.light();
                                setState(() => _quantityLoaded += 1);
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textMuted, letterSpacing: 1.0),
        ),
        const SizedBox(height: 4),
        Container(
          height: 44,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.glassBorder),
          ),
          child: TextField(
            controller: controller,
            textCapitalization: textCapitalization,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textPrimary,
              fontFamily: isMonospace ? 'monospace' : null,
              fontWeight: isMonospace ? FontWeight.bold : FontWeight.w500,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 11),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              border: InputBorder.none,
            ),
          ),
        ),
      ],
    );
  }
}
