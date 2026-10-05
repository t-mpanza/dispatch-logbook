import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/haptics.dart';
import '../../core/utils/id_generator.dart';
import '../../data/models/ibt_manifest.dart';
import '../../data/models/loading_sheet_trip.dart';
import '../../data/models/preset.dart';
import '../viewmodels/entries_viewmodel.dart';
import '../widgets/ibt_picker.dart';
import '../widgets/tags_input.dart';
import '../widgets/ui_kit.dart';
import '../entry_route.dart';

enum EntryKind { truckLoad, stocks, countNote }

/// THE single entry-creation flow. Every entry starts here with the same
/// shape: choose a kind (truck load / stocks run / count & note), fill the
/// kind's fields, create. No more parallel screens with different fields.
class NewEntryScreen extends StatefulWidget {
  final EntryKind initialKind;

  const NewEntryScreen({super.key, this.initialKind = EntryKind.truckLoad});

  @override
  State<NewEntryScreen> createState() => _NewEntryScreenState();
}

class _NewEntryScreenState extends State<NewEntryScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _regController = TextEditingController();
  final TextEditingController _driverController = TextEditingController();
  final TextEditingController _targetController = TextEditingController();

  List<String> _tags = ['despatch'];
  bool _withCounter = true;
  late EntryKind _kind = widget.initialKind;
  PresetKey _selectedPreset = PresetKey.CUSTOM;
  final List<IbtDocument> _ibtDocuments = [];

  static const _quickTemplates = [
    (icon: Icons.tire_repair_outlined, label: 'Tyre Count', title: 'TYRE COUNT', tag: 'tyres'),
    (icon: Icons.warning_amber_outlined, label: 'Tyre Issue', title: 'TYRE ISSUE', tag: 'issue'),
    (icon: Icons.person_off_outlined, label: 'Driver Issue', title: 'DRIVER ISSUE', tag: 'driver'),
    (icon: Icons.receipt_long_outlined, label: 'Invoice Mismatch', title: 'INVOICE MISMATCH', tag: 'invoice'),
    (icon: Icons.inventory_2_outlined, label: 'Missing Stock', title: 'MISSING STOCK', tag: 'stock'),
    (icon: Icons.schedule_outlined, label: 'Loading Delay', title: 'LOADING DELAY', tag: 'delay'),
    (icon: Icons.broken_image_outlined, label: 'Damage Report', title: 'DAMAGE REPORT', tag: 'damage'),
  ];

  @override
  void initState() {
    super.initState();
    _resetForKind(widget.initialKind);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _regController.dispose();
    _driverController.dispose();
    _targetController.dispose();
    super.dispose();
  }

  void _resetForKind(EntryKind kind) {
    _kind = kind;
    switch (kind) {
      case EntryKind.truckLoad:
        _withCounter = true;
        _selectPreset(PresetKey.CUSTOM);
      case EntryKind.stocks:
        _withCounter = false;
        _selectPreset(PresetKey.STOCKS);
      case EntryKind.countNote:
        _withCounter = true;
        _selectPreset(PresetKey.CUSTOM);
    }
  }

  void _switchKind(EntryKind kind) {
    AppHaptics.medium();
    setState(() => _resetForKind(kind));
  }

  Future<void> _selectPreset(PresetKey key) async {
    AppHaptics.light();
    setState(() => _selectedPreset = key);

    final vm = context.read<EntriesViewModel>();
    switch (key) {
      case PresetKey.DBN:
        _titleController.text = 'DBN';
        _ensureTag('dbn');
      case PresetKey.NLS:
        _titleController.text = 'NLS';
        _ensureTag('nls');
      case PresetKey.BLOEM:
        _titleController.text = 'BLOEM';
        _ensureTag('bloem');
      case PresetKey.PLK:
        _titleController.text = 'PLK';
        _ensureTag('plk');
      case PresetKey.STOCKS:
        final todayEntries = await vm.getTodayEntries();
        final titles = todayEntries.map((e) => e.title).toList();
        _titleController.text = PresetEngine.getNextStocksTripId(titles);
        _ensureTag('stocks');
      case PresetKey.NLH:
        _titleController.text = 'NLH';
        _regController.text = 'MN05XNGP';
        _driverController.text = 'Neil';
        _ensureTag('nlh');
      case PresetKey.TIREPOINT:
        _titleController.text = 'TIREPOINT';
        _ensureTag('tirepoint');
      case PresetKey.CUSTOM:
        _titleController.text =
            'TRIP - ${AppFormatters.formatTimeHHmm(DateTime.now().millisecondsSinceEpoch)}';
    }
  }

  void _ensureTag(String tag) {
    if (!_tags.contains(tag.toLowerCase()) && !_tags.contains(tag)) {
      setState(() => _tags = [..._tags, tag]);
    }
  }

  void _applyQuickTemplate({required String title, required String tag}) {
    AppHaptics.light();
    setState(() {
      _titleController.text = title;
      _selectedPreset = PresetKey.CUSTOM;
    });
    _ensureTag(tag);
  }

  Future<void> _handleCreate() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    AppHaptics.success();
    final vm = context.read<EntriesViewModel>();

    final isStocks = _kind == EntryKind.stocks;
    final isTruckLoad = _kind == EntryKind.truckLoad;
    final totalIbtTyres = _ibtDocuments.fold<int>(0, (s, d) => s + d.total);
    final target = int.tryParse(_targetController.text.trim());

    final entry = await vm.createEntry(
      title: title,
      tags: _tags,
      withCounter: _withCounter,
      expectedTotal: (isStocks && totalIbtTyres > 0)
          ? totalIbtTyres
          : (isTruckLoad ? target : null),
    );

    LoadingSheetTrip? sheetTrip;
    if (isStocks && _ibtDocuments.isNotEmpty) {
      final now = DateTime.now().millisecondsSinceEpoch;
      sheetTrip = LoadingSheetTrip(
        id: IdGenerator.generate(),
        tripId: title,
        reg: _regController.text.trim().toUpperCase(),
        driverName: _driverController.text.trim(),
        presetKey: PresetKey.STOCKS,
        quantityLoaded: 0,
        targetQuantity: totalIbtTyres > 0 ? totalIbtTyres : null,
        startTime: now,
        createdAt: now,
        ibtDocuments: _ibtDocuments,
      );
    } else if (isTruckLoad && _selectedPreset != PresetKey.CUSTOM) {
      final now = DateTime.now().millisecondsSinceEpoch;
      sheetTrip = LoadingSheetTrip(
        id: IdGenerator.generate(),
        tripId: title,
        reg: _regController.text.trim().toUpperCase(),
        driverName: _driverController.text.trim(),
        presetKey: _selectedPreset,
        quantityLoaded: 0,
        targetQuantity: target,
        startTime: now,
        createdAt: now,
      );
    }

    var updated = entry;
    if (sheetTrip != null) {
      updated = entry.copyWith(
        loadingSheetTrips: [sheetTrip.copyWith(entryId: entry.id)],
      );
      await vm.updateEntry(updated);
    }

    if (!mounted) return;
    openEntryDetailReplacing(context, updated);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () {
            AppHaptics.light();
            Navigator.pop(context);
          },
        ),
        title: const Text('New entry'),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              children: [
                // ── ONE kind selector for every entry ──
                Row(
                  children: [
                    Expanded(
                      child: _kindChip(EntryKind.truckLoad, Icons.local_shipping_rounded, 'TRUCK LOAD'),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _kindChip(EntryKind.stocks, Icons.inventory_2_rounded, 'STOCKS RUN'),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _kindChip(EntryKind.countNote, Icons.note_add_rounded, 'COUNT · NOTE'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                if (_kind == EntryKind.truckLoad) ...[
                  _fieldLabel(context, 'WHERE IS IT GOING?'),
                  const SizedBox(height: 8),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 3.1,
                    children: [
                      for (final preset in PresetEngine.loadingPresets)
                        if (preset.key != PresetKey.STOCKS)
                          _PresetCard(
                            preset: preset,
                            selected: _selectedPreset == preset.key,
                            onTap: () => _selectPreset(preset.key),
                          ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _fieldLabel(context, 'TRUCK DETAILS'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _regController,
                          textCapitalization: TextCapitalization.characters,
                          decoration: const InputDecoration(labelText: 'REG'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _driverController,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(labelText: 'DRIVER'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _targetController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'TARGET TYRES',
                      hintText: 'e.g. 180',
                    ),
                  ),
                  const SizedBox(height: 18),
                ],

                if (_kind == EntryKind.stocks) ...[
                  _fieldLabel(context, 'IBT DOCUMENTS'),
                  const SizedBox(height: 8),
                  AppCard(
                    padding: const EdgeInsets.all(14),
                    child: IbtPicker(
                      documents: _ibtDocuments,
                      onChanged: (docs) {
                        setState(
                          () => _ibtDocuments
                            ..clear()
                            ..addAll(docs),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 18),
                ],

                if (_kind == EntryKind.countNote) ...[
                  _fieldLabel(context, 'QUICK TEMPLATES'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final tmpl in _quickTemplates)
                        GestureDetector(
                          onTap: () => _applyQuickTemplate(
                            title: tmpl.title,
                            tag: tmpl.tag,
                          ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.dynamicCardSurface(context),
                              borderRadius: BorderRadius.circular(100),
                              border: Border.all(
                                color: AppColors.dynamicBorderLight(context),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  tmpl.icon,
                                  size: 15,
                                  color: AppColors.dynamicTextSecondary(context),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  tmpl.label,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.dynamicTextPrimary(context),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),
                ],

                if (_kind != EntryKind.stocks) ...[
                  _fieldLabel(context, 'ENTRY NAME'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _titleController,
                    textCapitalization: TextCapitalization.characters,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.dynamicTextPrimary(context),
                      letterSpacing: 0.5,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'e.g. NLS or STOCKS 1',
                    ),
                  ),
                  const SizedBox(height: 18),
                ],

                _fieldLabel(context, 'TAGS'),
                const SizedBox(height: 8),
                TagsInput(
                  value: _tags,
                  onChange: (tags) => setState(() => _tags = tags),
                  suggestions: const [
                    'despatch',
                    'tyres',
                    'stocks',
                    'nlh',
                    'dbn',
                    'bloem',
                    'plk',
                    'tirepoint',
                    'issue',
                    'driver',
                    'invoice',
                    'delay',
                    'damage',
                  ],
                ),
                const SizedBox(height: 18),

                if (_kind != EntryKind.stocks)
                  AppCard(
                    onTap: () => setState(() => _withCounter = !_withCounter),
                    child: Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: AppColors.presetStocks.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.exposure_plus_1_rounded,
                            color: AppColors.presetStocks,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Tyre counter',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.dynamicTextPrimary(context),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Tally tyres as you load, feeds the sheet',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.dynamicTextMuted(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: _withCounter,
                          onChanged: (val) => setState(() => _withCounter = val),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton.icon(
                onPressed: _handleCreate,
                icon: const Icon(Icons.arrow_forward_rounded, size: 22),
                label: const Text('Create entry'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _kindChip(EntryKind kind, IconData icon, String label) {
    final active = _kind == kind;
    final color = switch (kind) {
      EntryKind.truckLoad => AppColors.presetNls,
      EntryKind.stocks => AppColors.presetStocks,
      EntryKind.countNote => AppColors.presetNlh,
    };
    return GestureDetector(
      onTap: () => _switchKind(kind),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: active ? color.withValues(alpha: 0.16) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: active ? color.withValues(alpha: 0.5) : AppColors.dynamicBorder(context),
          ),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: active ? color : AppColors.dynamicTextMuted(context)),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: active ? FontWeight.w900 : FontWeight.w600,
                letterSpacing: 0.4,
                color: active ? color : AppColors.dynamicTextMuted(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fieldLabel(BuildContext context, String label) {
    return Text(label, style: Theme.of(context).textTheme.labelSmall);
  }
}

class _PresetCard extends StatelessWidget {
  final PresetConfig preset;
  final bool selected;
  final VoidCallback onTap;

  const _PresetCard({
    required this.preset,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = presetColor(preset.key, preset.key.name);
    return GestureDetector(
      onTap: () {
        AppHaptics.light();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.2)
              : AppColors.dynamicBackgroundSecondary(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? color : AppColors.dynamicBorderLight(context),
            width: selected ? 1.6 : 1,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                preset.label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                  color: selected
                      ? AppColors.dynamicTextPrimary(context)
                      : AppColors.dynamicTextSecondary(context),
                ),
              ),
            ),
            if (selected)
              Icon(Icons.check_circle_rounded, size: 18, color: color),
          ],
        ),
      ),
    );
  }
}
