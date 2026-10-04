import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/glass_decorations.dart';
import '../../core/utils/haptics.dart';
import 'dispatch_board_screen.dart';
import 'dispatch_inspect_screen.dart';
import 'dispatch_lookup_screen.dart';
import 'dispatch_summary_screen.dart';

/// The Dispatch Hub — live warehouse ops views fused from the DispatchApp
/// v3 Tyre Inspector: board, lookup, inspect (lite text-input mode) and
/// day summary. Powered by the shared ATT AppSync backend.
class DispatchHubScreen extends StatefulWidget {
  const DispatchHubScreen({super.key});

  @override
  State<DispatchHubScreen> createState() => _DispatchHubScreenState();
}

class _DispatchHubScreenState extends State<DispatchHubScreen> {
  int _tab = 0;

  static const List<Widget> _tabs = [
    DispatchBoardScreen(),
    DispatchLookupScreen(),
    DispatchInspectScreen(),
    DispatchSummaryScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.info.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.radar_rounded,
                      color: AppColors.info,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'DISPATCH HUB',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                          color: AppColors.info,
                        ),
                      ),
                      Text(
                        'Live warehouse intelligence',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.dynamicTextMuted(context),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: _SegmentedTabs(index: _tab, onChanged: (i) {
                AppHaptics.light();
                setState(() => _tab = i);
              }),
            ),
            Expanded(child: IndexedStack(index: _tab, children: _tabs)),
          ],
        ),
      ),
    );
  }
}

class _SegmentedTabs extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChanged;

  const _SegmentedTabs({required this.index, required this.onChanged});

  static const List<(IconData, String)> _items = [
    (Icons.dashboard_rounded, 'Board'),
    (Icons.search_rounded, 'Lookup'),
    (Icons.fact_check_rounded, 'Inspect'),
    (Icons.assessment_rounded, 'Summary'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: GlassDecorations.glassDock(context: context, borderRadius: 16),
      child: Row(
        children: [
          for (var i = 0; i < _items.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    color: index == i
                        ? AppColors.info.withValues(alpha: 0.18)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: index == i
                          ? AppColors.info.withValues(alpha: 0.45)
                          : Colors.transparent,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        _items[i].$1,
                        size: 18,
                        color: index == i
                            ? AppColors.info
                            : AppColors.dynamicTextMuted(context),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _items[i].$2,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight:
                              index == i ? FontWeight.w900 : FontWeight.w600,
                          color: index == i
                              ? AppColors.info
                              : AppColors.dynamicTextMuted(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
