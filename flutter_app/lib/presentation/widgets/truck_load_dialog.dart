import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/haptics.dart';
import '../../core/utils/id_generator.dart';
import '../../data/models/ibt_manifest.dart';
import '../../data/models/loading_sheet_trip.dart';
import '../../data/models/preset.dart';
import '../../data/services/appsync_manifest_service.dart';
import 'aws_auth_dialog.dart';

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
  final TextEditingController _ibtInputController = TextEditingController();

  int _quantityLoaded = 0;
  List<IbtDocument> _ibtDocuments = [];
  bool _isFetchingIbt = false;

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
      _startController =
          TextEditingController(text: AppFormatters.formatTimeHHmm(t.startTime));
      _finishController =
          TextEditingController(text: AppFormatters.formatTimeHHmm(t.finishTime));
      _quantityLoaded = t.quantityLoaded;
      _ibtDocuments = List.from(t.ibtDocuments ?? []);
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
      _ibtDocuments = [];
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

  Future<void> _onFetchIbt() async {
    final text = _ibtInputController.text.trim();
    if (text.isEmpty) return;

    AppHaptics.light();
    setState(() {
      _isFetchingIbt = true;
    });

    try {
      final doc = await AppSyncManifestService.fetchIbtDocument(text);
      AppHaptics.medium();

      setState(() {
        final existingIdx = _ibtDocuments.indexWhere(
          (d) => d.documentNo.toUpperCase() == doc.documentNo.toUpperCase(),
        );

        if (existingIdx >= 0) {
          _ibtDocuments[existingIdx] = doc;
        } else {
          _ibtDocuments.add(doc);
        }

        // Auto-fill / update loaded & target tyre counts
        final totalIbtTyres =
            _ibtDocuments.fold<int>(0, (s, d) => s + d.total);
        if (_quantityLoaded == 0 || _quantityLoaded < totalIbtTyres) {
          _quantityLoaded = totalIbtTyres;
        }

        _ibtInputController.clear();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to fetch IBT: $e'),
            backgroundColor: Colors.redAccent,
            action: SnackBarAction(
              label: 'AWS Login',
              textColor: Colors.white,
              onPressed: () => AwsAuthDialog.show(context),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isFetchingIbt = false;
        });
      }
    }
  }

  void _onRemoveIbt(String documentNo) {
    AppHaptics.light();
    setState(() {
      _ibtDocuments.removeWhere(
        (d) => d.documentNo.toUpperCase() == documentNo.toUpperCase(),
      );
    });
  }

  void _handleSave() {
    AppHaptics.success();
    final now = DateTime.now().millisecondsSinceEpoch;
    final baseDateMs = widget.existingTrip?.createdAt ??
        (DateTime.tryParse(widget.dayKey)?.millisecondsSinceEpoch ?? now);

    final startMs =
        AppFormatters.timeStringToMs(_startController.text, baseDateMs);
    final finishMs =
        AppFormatters.timeStringToMs(_finishController.text, baseDateMs);

    int? duration;
    if (startMs != null && finishMs != null) {
      final diff = finishMs - startMs;
      duration = diff > 0 ? (diff / (1000 * 60)).round() : 1;
    }

    final totalIbtTarget =
        _ibtDocuments.fold<int>(0, (s, d) => s + d.total);

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
      targetQuantity: totalIbtTarget > 0 ? totalIbtTarget : null,
      isManual: widget.existingTrip?.isManual ?? false,
      createdAt: widget.existingTrip?.createdAt ?? startMs ?? now,
      ibtDocuments: (_selectedPreset == PresetKey.STOCKS && _ibtDocuments.isNotEmpty)
          ? _ibtDocuments
          : null,
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
    _ibtInputController.dispose();
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

            // Header Title
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isEdit ? 'Edit Truck Load' : 'Add Truck Load',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (isEdit && widget.onDelete != null)
                  IconButton(
                    icon: const Icon(Icons.delete_outline,
                        color: Colors.redAccent),
                    onPressed: () {
                      AppHaptics.heavy();
                      widget.onDelete!();
                      Navigator.pop(context);
                    },
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // Presets Selector
            const Text(
              'Trip Preset',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: PresetKey.values.map((preset) {
                final isSelected = _selectedPreset == preset;
                return ChoiceChip(
                  label: Text(preset.name),
                  selected: isSelected,
                  onSelected: (_) => _onPresetChanged(preset),
                  selectedColor: AppColors.primaryGlow.withValues(alpha: 0.25),
                  backgroundColor: AppColors.glassSurfaceElevated,
                  labelStyle: TextStyle(
                    color: isSelected ? AppColors.primaryGlow : Colors.white70,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 12,
                  ),
                  side: BorderSide(
                    color: isSelected ? AppColors.primaryGlow : Colors.white10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // IBT Manifest Document Input Section (ONLY APPEARS FOR STOCKS)
            if (_selectedPreset == PresetKey.STOCKS) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.glassSurfaceElevated,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _ibtDocuments.isNotEmpty
                        ? AppColors.primaryGlow.withValues(alpha: 0.3)
                        : Colors.white10,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.receipt_long_outlined,
                              size: 16,
                              color: AppColors.primaryGlow,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'IBT Document Number',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        InkWell(
                          onTap: () => AwsAuthDialog.show(context),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.vpn_key_outlined, size: 10, color: AppColors.primaryGlow),
                                SizedBox(width: 4),
                                Text(
                                  'AWS Auth',
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primaryGlow),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _ibtInputController,
                            textCapitalization: TextCapitalization.characters,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 13),
                            decoration: InputDecoration(
                              hintText: 'e.g. IBT119512 or 119512',
                              hintStyle: TextStyle(
                                color: Colors.white.withValues(alpha: 0.3),
                                fontSize: 12,
                              ),
                              filled: true,
                              fillColor: Colors.black26,
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            onSubmitted: (_) => _onFetchIbt(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _isFetchingIbt ? null : _onFetchIbt,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryGlow,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: _isFetchingIbt
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.black,
                                  ),
                                )
                              : const Text(
                                  'Fetch IBT',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                        ),
                      ],
                    ),

                    // Display Attached IBT Chips
                    if (_ibtDocuments.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _ibtDocuments.map((doc) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primaryGlow.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: AppColors.primaryGlow.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${doc.documentNo} (${doc.total} tyres • ${doc.lineItems.length} sizes)',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                InkWell(
                                  onTap: () => _onRemoveIbt(doc.documentNo),
                                  child: const Icon(
                                    Icons.close,
                                    size: 14,
                                    color: Colors.white70,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Form Fields: Trip ID & Vehicle Reg
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    label: 'Trip ID',
                    controller: _tripIdController,
                    hint: 'e.g. DBN or STOCKS 1',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTextField(
                    label: 'Vehicle Reg',
                    controller: _regController,
                    hint: 'e.g. MN05XNGP',
                    capitalization: TextCapitalization.characters,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Driver Name
            _buildTextField(
              label: 'Driver Name',
              controller: _driverController,
              hint: 'e.g. Neil, Sipho',
            ),
            const SizedBox(height: 12),

            // Start & Finish Times
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    label: 'Start Time',
                    controller: _startController,
                    hint: 'HH:mm (e.g. 07:30)',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTextField(
                    label: 'Finish Time',
                    controller: _finishController,
                    hint: 'HH:mm (e.g. 08:15)',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Quantity Loaded Stepper
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.glassSurfaceElevated,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Total Tyres Loaded',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (_ibtDocuments.isNotEmpty)
                        Text(
                          'From ${_ibtDocuments.length} IBT Document(s)',
                          style: TextStyle(
                            color: AppColors.primaryGlow.withValues(alpha: 0.8),
                            fontSize: 11,
                          ),
                        ),
                    ],
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline,
                            color: Colors.white70),
                        onPressed: _quantityLoaded > 0
                            ? () {
                                AppHaptics.light();
                                setState(() => _quantityLoaded--);
                              }
                            : null,
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black26,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '$_quantityLoaded',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline,
                            color: AppColors.primaryGlow),
                        onPressed: () {
                          AppHaptics.light();
                          setState(() => _quantityLoaded++);
                        },
                      ),
                      const SizedBox(width: 4),
                      TextButton(
                        onPressed: () {
                          AppHaptics.light();
                          setState(() => _quantityLoaded += 5);
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          backgroundColor: Colors.white.withValues(alpha: 0.08),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6)),
                        ),
                        child: const Text(
                          '+5',
                          style: TextStyle(
                              color: Colors.white70, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Save Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _handleSave,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGlow,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  isEdit ? 'Update Trip' : 'Add Trip to Loading Sheet',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
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
    TextCapitalization capitalization = TextCapitalization.words,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          textCapitalization: capitalization,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: Colors.white.withValues(alpha: 0.3),
              fontSize: 13,
            ),
            filled: true,
            fillColor: AppColors.glassSurfaceElevated,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.primaryGlow),
            ),
          ),
        ),
      ],
    );
  }
}
