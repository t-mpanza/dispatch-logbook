import re

with open("flutter_app/lib/presentation/widgets/counter_panel.dart", "r") as f:
    content = f.read()

# 1. Add fields to constructor
content = re.sub(
    r"final Function\(Attachment\)\? onAttachment;\n\n  const CounterPanel\({",
    r"final Function(Attachment)? onAttachment;\n  final int currentTotal;\n  final int? targetTotal;\n\n  const CounterPanel({\n    this.currentTotal = 0,\n    this.targetTotal,",
    content
)

# 2. Add _warnIfOver before _logScanned
warn_if_over = """
  Future<bool> _warnIfOver(BuildContext context, int adding) async {
    final target = widget.targetTotal;
    if (target == null || target <= 0) return true;
    final afterAdd = widget.currentTotal + adding;
    if (afterAdd <= target) return true;

    final over = afterAdd - target;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.backgroundSecondary,
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 20),
            SizedBox(width: 8),
            Text('Over IBT Target', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          ],
        ),
        content: Text(
          'Adding $adding tyres will put you $over over the target of $target.\\n\\nAre you sure you want to continue?',
          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.warning),
            child: Text('Log +$over over anyway', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  void _logScanned() async {"""

content = re.sub(r"  void _logScanned\(\) {", warn_if_over, content)

# 3. Modify _logScanned body
content = re.sub(
    r"    if \(_count <= 0\) return;\n    AppHaptics\.success\(\);",
    r"    if (_count <= 0) return;\n    final ok = await _warnIfOver(context, _count);\n    if (!ok) return;\n    AppHaptics.success();",
    content
)

# 4. Modify _logManual body
content = re.sub(
    r"  void _logManual\(\{String\? noteOverride\}\) {\n    if \(_manualCount <= 0\) return;\n    AppHaptics\.success\(\);",
    r"  void _logManual({String? noteOverride}) async {\n    if (_manualCount <= 0) return;\n    final ok = await _warnIfOver(context, _manualCount);\n    if (!ok) return;\n    AppHaptics.success();",
    content
)

with open("flutter_app/lib/presentation/widgets/counter_panel.dart", "w") as f:
    f.write(content)
