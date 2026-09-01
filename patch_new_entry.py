import re

with open("flutter_app/lib/presentation/screens/new_entry_screen.dart", "r") as f:
    content = f.read()

# 1. Imports
imports = """import '../../core/theme/glass_decorations.dart';
import '../../data/models/ibt_manifest.dart';
import '../../data/models/loading_sheet_trip.dart';
import '../../core/utils/id_generator.dart';
import '../../data/services/appsync_manifest_service.dart';
import '../widgets/aws_auth_dialog.dart';"""

content = re.sub(
    r"import '\.\./\.\./core/theme/glass_decorations\.dart';",
    imports,
    content
)

# 2. State fields
fields = """  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _ibtInputController = TextEditingController();

  List<String> _tags = ['despatch'];
  bool _withCounter = true;
  PresetKey _selectedPreset = PresetKey.CUSTOM;

  final List<IbtDocument> _ibtDocuments = [];
  bool _isFetchingIbt = false;"""

content = re.sub(
    r"  final TextEditingController _titleController = TextEditingController\(\);\n\n  List<String> _tags = \['despatch'\];\n  bool _withCounter = true;\n  PresetKey _selectedPreset = PresetKey\.CUSTOM;",
    fields,
    content
)

# 3. Dispose
dispose = """  @override
  void dispose() {
    _titleController.dispose();
    _ibtInputController.dispose();
    super.dispose();
  }"""

content = re.sub(
    r"  @override\n  void dispose\(\) {\n    _titleController\.dispose\(\);\n    super\.dispose\(\);\n  }",
    dispose,
    content
)

# 4. Fetch / Remove Methods
methods = """  Future<void> _onFetchIbt() async {
    final text = _ibtInputController.text.trim();
    if (text.isEmpty) return;

    AppHaptics.light();
    setState(() => _isFetchingIbt = true);

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
        setState(() => _isFetchingIbt = false);
      }
    }
  }

  void _onRemoveIbt(String docNo) {
    AppHaptics.light();
    setState(() {
      _ibtDocuments.removeWhere(
        (d) => d.documentNo.toUpperCase() == docNo.toUpperCase(),
      );
    });
  }

  Color _getPresetColor"""

content = re.sub(r"  Color _getPresetColor", methods, content)

# 5. createEntry logic
create_logic_old = """    final entry = await vm.createEntry(
      title: title,
      tags: _tags,
      withCounter: _withCounter,
      presetKey: _selectedPreset,
      presetPrefix: presetTag,
    );"""

create_logic_new = """    int? expectedTotal;
    if (_ibtDocuments.isNotEmpty) {
      expectedTotal = _ibtDocuments.fold(0, (sum, doc) => sum + doc.total);
    }

    final entry = await vm.createEntry(
      title: title,
      tags: _tags,
      withCounter: _withCounter,
      presetKey: _selectedPreset,
      presetPrefix: presetTag,
      expectedTotal: expectedTotal,
    );

    // If we have IBTs, create an initial trip and attach them
    if (_ibtDocuments.isNotEmpty && _withCounter) {
      final presetCfg = PresetEngine.presets[_selectedPreset];
      final reg = presetCfg?.defaultReg ?? '';
      final driver = presetCfg?.defaultDriver ?? '';

      final trip = LoadingSheetTrip(
        id: IdGenerator.generate(),
        entryId: entry.id,
        reg: reg,
        driverName: driver,
        tripId: '', // Set by loading sheet viewmodel
        presetKey: _selectedPreset,
        quantityLoaded: 0,
        targetQuantity: expectedTotal,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        ibtDocuments: _ibtDocuments,
      );
      
      // We don't have LoadingSheetViewModel here directly, but we can update the entry's local cache
      // The actual trip persistence happens via LoadingSheetViewModel in real usage, 
      // but for NewEntryScreen we might just pass the trip along or let the entry view handle it.
      // Actually, looking at main, `createEntry` just makes the entry.
      // The IBT branch had specific logic to inject the trip into the LoadingSheetViewModel.
      // We'll skip that complex injection if it's not strictly necessary, or we can use Provider to get it.
    }"""
# Wait, the IBT branch just passed expectedTotal, it didn't create a trip directly in NewEntryScreen.
# Let's check the git diff for _createEntry.
