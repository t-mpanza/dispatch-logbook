import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/glass_decorations.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/haptics.dart';
import '../../data/models/preset.dart';
import '../viewmodels/entries_viewmodel.dart';
import '../widgets/tags_input.dart';
import 'entry_detail_screen.dart';

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

  @override
  void initState() {
    super.initState();
    _titleController.text =
        'TRIP - ${AppFormatters.formatTimeHHmm(DateTime.now().millisecondsSinceEpoch)}';
  }

  Future<void> _selectPreset(PresetKey key) async {
    AppHaptics.light();
    setState(() => _selectedPreset = key);

    final vm = context.read<EntriesViewModel>();

    switch (key) {
      case PresetKey.DBN:
        _titleController.text = 'DBN';
        _ensureTag('dbn');
        break;
      case PresetKey.NLS:
        _titleController.text = 'NLS';
        _ensureTag('nls');
        break;
      case PresetKey.BLOEM:
        _titleController.text = 'BLOEM';
        _ensureTag('bloem');
        break;
      case PresetKey.PLK:
        _titleController.text = 'PLK';
        _ensureTag('plk');
        break;
      case PresetKey.STOCKS:
        final todayEntries = await vm.getTodayEntries();
        final titles = todayEntries.map((e) => e.title).toList();
        final stocksId = PresetEngine.getNextStocksTripId(titles);
        _titleController.text = stocksId;
        _ensureTag('stocks');
        break;
      case PresetKey.NLH:
        _titleController.text = 'NLH';
        _ensureTag('nlh');
        _ensureTag('Neil');
        _ensureTag('MN05XNGP');
        break;
      case PresetKey.TIREPOINT:
        _titleController.text = 'TIREPOINT';
        _ensureTag('tirepoint');
        break;
      case PresetKey.CUSTOM:
        _titleController.text =
            'TRIP - ${AppFormatters.formatTimeHHmm(DateTime.now().millisecondsSinceEpoch)}';
        break;
    }
  }

  void _ensureTag(String tag) {
    if (!_tags.contains(tag.toLowerCase()) && !_tags.contains(tag)) {
      setState(() {
        _tags = [..._tags, tag];
      });
    }
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
    final entry = await vm.createEntry(
      title: title,
      tags: _tags,
      withCounter: _withCounter,
    );

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => EntryDetailScreen(entryId: entry.id)),
      );
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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'New Trip Entry',
          style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Quick Route Presets Selector
            const Text(
              'ROUTE PRESETS',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: AppColors.textMuted,
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
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? color.withValues(alpha: 0.25)
                          : AppColors.glassSurface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? color
                            : Colors.white.withValues(alpha: 0.08),
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
                                ? AppColors.textPrimary
                                : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // Title input
            const Text(
              'ENTRY TITLE',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: AppColors.textMuted,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: GlassDecorations.glassCard(borderRadius: 16),
              child: TextField(
                controller: _titleController,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  hintText: 'e.g. NLS or STOCKS 1',
                  hintStyle: TextStyle(color: AppColors.textMuted),
                  border: InputBorder.none,
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Tags input
            const Text(
              'TAGS',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: AppColors.textMuted,
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
                'tirepoint'
              ],
            ),
            const SizedBox(height: 20),

            // With Counter Switch
            Container(
              padding: const EdgeInsets.all(14),
              decoration: GlassDecorations.glassCard(borderRadius: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Include Tyre Counter',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary),
                      ),
                      Text(
                        'Enables trip counting & digital loading sheet',
                        style: TextStyle(
                            fontSize: 11, color: AppColors.textMuted),
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
                      borderRadius: BorderRadius.circular(16)),
                  elevation: 8,
                ),
                child: const Text(
                  'Create Trip Entry',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
