import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/glass_decorations.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/haptics.dart';
import '../../core/utils/id_generator.dart';
import '../../data/models/ibt_manifest.dart';
import '../../data/models/loading_sheet_trip.dart';
import '../../data/models/preset.dart';
import '../viewmodels/entries_viewmodel.dart';
import '../widgets/ibt_picker.dart';
import '../widgets/tags_input.dart';
import 'entry_detail_screen.dart';
import 'stocks_entry_detail_screen.dart';

class NewEntryScreen extends StatefulWidget {
  const NewEntryScreen({super.key});

  @override
  State<NewEntryScreen> createState() => _NewEntryScreenState();
}

class _NewEntryScreenState extends State<NewEntryScreen> {
  final TextEditingController _titleController = TextEditingController();
  List<String> _tags = ['despatch'];
  bool _withCounter = true;
  PresetKey _selectedPreset = PresetKey.CUSTOM;

  final List<IbtDocument> _ibtDocuments = [];

  static const _quickTemplates = [
    (
      icon: Icons.tire_repair_outlined,
      label: 'Tyre Count',
      title: 'TYRE COUNT',
      tag: 'tyres',
    ),
    (
      icon: Icons.warning_amber_outlined,
      label: 'Tyre Issue',
      title: 'TYRE ISSUE',
      tag: 'issue',
    ),
    (
      icon: Icons.person_off_outlined,
      label: 'Driver Issue',
      title: 'DRIVER ISSUE',
      tag: 'driver',
    ),
    (
      icon: Icons.receipt_long_outlined,
      label: 'Invoice Mismatch',
      title: 'INVOICE MISMATCH',
      tag: 'invoice',
    ),
    (
      icon: Icons.inventory_2_outlined,
      label: 'Missing Stock',
      title: 'MISSING STOCK',
      tag: 'stock',
    ),
    (
      icon: Icons.schedule_outlined,
      label: 'Loading Delay',
      title: 'LOADING DELAY',
      tag: 'delay',
    ),
    (
      icon: Icons.broken_image_outlined,
      label: 'Damage Report',
      title: 'DAMAGE REPORT',
      tag: 'damage',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _titleController.text =
        'TRIP - ${AppFormatters.formatTimeHHmm(DateTime.now().millisecondsSinceEpoch)}';
  }

  Future<void> _selectPreset(PresetKey key) async {
    AppHaptics.light();

    final vm = context.read<EntriesViewModel>();

    String title;
    final List<String> extraTags = [];

    switch (key) {
      case PresetKey.DBN:
        title = 'DBN';
        extraTags.add('dbn');
        break;
      case PresetKey.NLS:
        title = 'NLS';
        extraTags.add('nls');
        break;
      case PresetKey.BLOEM:
        title = 'BLOEM';
        extraTags.add('bloem');
        break;
      case PresetKey.PLK:
        title = 'PLK';
        extraTags.add('plk');
        break;
      case PresetKey.STOCKS:
        final todayEntries = await vm.getTodayEntries();
        final titles = todayEntries.map((e) => e.title).toList();
        title = PresetEngine.getNextStocksTripId(titles);
        extraTags.add('stocks');
        break;
      case PresetKey.NLH:
        title = 'NLH';
        extraTags.addAll(['nlh', 'Neil', 'MN05XNGP']);
        break;
      case PresetKey.TIREPOINT:
        title = 'TIREPOINT';
        extraTags.add('tirepoint');
        break;
      case PresetKey.CUSTOM:
        title = 'TRIP - ${AppFormatters.formatTimeHHmm(DateTime.now().millisecondsSinceEpoch)}';
        break;
    }

    if (!mounted) return;

    setState(() {
      _selectedPreset = key;
      _titleController.text = title;
      for (final tag in extraTags) {
        if (!_tags.any((t) => t.toLowerCase() == tag.toLowerCase())) {
          _tags = [..._tags, tag];
        }
      }
    });
  }

  List<String> _withTag(List<String> current, String tag) {
    if (current.any((t) => t.toLowerCase() == tag.toLowerCase())) {
      return current;
    }
    return [...current, tag];
  }

  void _applyQuickTemplate({required String title, required String tag}) {
    AppHaptics.light();
    setState(() {
      _titleController.text = title;
      _selectedPreset = PresetKey.CUSTOM;
      _tags = _withTag(_tags, tag);
    });
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

  Future<void> _handleCreate() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    AppHaptics.success();
    final vm = context.read<EntriesViewModel>();

    final isStocks = _selectedPreset == PresetKey.STOCKS;
    final totalIbtTyres = _ibtDocuments.fold<int>(0, (s, d) => s + d.total);

    LoadingSheetTrip? initialTrip;
    if (isStocks && _ibtDocuments.isNotEmpty) {
      final now = DateTime.now().millisecondsSinceEpoch;
      initialTrip = LoadingSheetTrip(
        id: IdGenerator.generate(),
        tripId: title,
        reg: '',
        driverName: '',
        presetKey: _selectedPreset,
        quantityLoaded: 0,
        targetQuantity: totalIbtTyres > 0 ? totalIbtTyres : null,
        startTime: now,
        createdAt: now,
        ibtDocuments: _ibtDocuments,
      );
    }

    final entry = await vm.createEntry(
      title: title,
      tags: _tags,
      withCounter: _withCounter,
      expectedTotal: (isStocks && totalIbtTyres > 0) ? totalIbtTyres : null,
    );

    if (initialTrip != null) {
      final updatedEntry = entry.copyWith(
        loadingSheetTrips: [initialTrip.copyWith(entryId: entry.id)],
      );
      await vm.updateEntry(updatedEntry);
    }

    if (mounted) {
      if (isStocks) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => StocksEntryDetailScreen(entryId: entry.id),
          ),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => EntryDetailScreen(entryId: entry.id),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.dynamicBackground(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(
            Icons.close_rounded,
            color: AppColors.dynamicTextPrimary(context),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'New Trip Entry',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.dynamicTextPrimary(context),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Quick Route Presets Selector
            Text(
              'ROUTE PRESETS',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: AppColors.dynamicTextMuted(context),
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: PresetEngine.loadingPresets.map((preset) {
                final isSelected = _selectedPreset == preset.key;
                final color = _getPresetColor(preset.key);

                return GestureDetector(
                  onTap: () => _selectPreset(preset.key),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? color.withValues(alpha: 0.25)
                          : AppColors.dynamicCardSurface(context),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? color
                            : AppColors.dynamicBorder(context),
                        width: isSelected ? 1.5 : 1.0,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          preset.label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.w600,
                            color: isSelected
                                ? AppColors.dynamicTextPrimary(context)
                                : AppColors.dynamicTextSecondary(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Quick Entry Templates (non-delivery events)
            Text(
              'QUICK TEMPLATES',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: AppColors.dynamicTextMuted(context),
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _quickTemplates.map((tmpl) {
                return GestureDetector(
                  onTap: () =>
                      _applyQuickTemplate(title: tmpl.title, tag: tmpl.tag),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.dynamicCardSurface(context),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.dynamicBorder(context),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          tmpl.icon,
                          size: 13,
                          color: AppColors.dynamicTextMuted(context),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          tmpl.label,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.dynamicTextSecondary(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // IBT Section (ONLY VISIBLE WHEN STOCKS PRESET IS SELECTED)
            if (_selectedPreset == PresetKey.STOCKS) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: GlassDecorations.glassCard(
                  context: context,
                  borderRadius: 16,
                  borderColor: _ibtDocuments.isNotEmpty
                      ? AppColors.primaryGlow.withValues(alpha: 0.35)
                      : null,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.receipt_long_rounded,
                          color: AppColors.isLight(context)
                              ? AppColors.primary
                              : AppColors.primaryGlow,
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Attach IBT Documents (Stocks)',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.dynamicTextPrimary(context),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Paste or type one or many IBT numbers — comma or space separated.',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.dynamicTextMuted(context),
                      ),
                    ),
                    const SizedBox(height: 10),
                    IbtPicker(
                      documents: _ibtDocuments,
                      onChanged: (docs) {
                        setState(() => _ibtDocuments
                          ..clear()
                          ..addAll(docs));
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Title input
            Text(
              'ENTRY TITLE',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: AppColors.dynamicTextMuted(context),
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: GlassDecorations.glassCard(
                context: context,
                borderRadius: 16,
              ),
              child: TextField(
                controller: _titleController,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.dynamicTextPrimary(context),
                ),
                decoration: InputDecoration(
                  hintText: 'e.g. NLS or STOCKS 1',
                  hintStyle: TextStyle(
                    color: AppColors.dynamicTextMuted(context),
                  ),
                  border: InputBorder.none,
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Tags input
            Text(
              'TAGS',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: AppColors.dynamicTextMuted(context),
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 6),
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
            const SizedBox(height: 20),

            // With Counter Switch
            Container(
              padding: const EdgeInsets.all(14),
              decoration: GlassDecorations.glassCard(
                context: context,
                borderRadius: 16,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Include Tyre Counter',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.dynamicTextPrimary(context),
                        ),
                      ),
                      Text(
                        'Enables trip counting & digital loading sheet',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.dynamicTextMuted(context),
                        ),
                      ),
                    ],
                  ),
                  Switch(
                    value: _withCounter,
                    activeThumbColor: AppColors.primaryGlow,
                    onChanged: (val) {
                      AppHaptics.light();
                      setState(() => _withCounter = val);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Create button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _handleCreate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 8,
                ),
                child: const Text(
                  'Create Trip Entry',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
