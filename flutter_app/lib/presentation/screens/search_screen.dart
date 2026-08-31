import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/glass_decorations.dart';
import '../../core/utils/haptics.dart';
import '../../data/models/entry.dart';
import '../viewmodels/entries_viewmodel.dart';
import '../widgets/swipeable_entry_card.dart';
import 'entry_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<EntriesViewModel>(
      builder: (context, vm, _) {
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
            children: [
              // Header
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SEARCH',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryGlow,
                      letterSpacing: 2.0,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Find Anything',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Search Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: GlassDecorations.glassCard(borderRadius: 18),
                child: Row(
                  children: [
                    const Icon(Icons.search_rounded, color: AppColors.primaryGlow, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        autofocus: false,
                        style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
                        decoration: const InputDecoration(
                          hintText: 'Reg, trip ID, driver, tag, note…',
                          hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 13),
                          border: InputBorder.none,
                        ),
                        onChanged: (val) {
                          setState(() => _query = val.trim());
                        },
                      ),
                    ),
                    if (_query.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 16, color: AppColors.textMuted),
                        onPressed: () {
                          AppHaptics.light();
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Popular Tags
              FutureBuilder<List<String>>(
                future: vm.getAllTags(),
                builder: (context, snapshot) {
                  final tags = snapshot.data ?? [];
                  if (tags.isEmpty) return const SizedBox.shrink();

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'POPULAR TAGS',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textMuted, letterSpacing: 1.0),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final tag in tags)
                            GestureDetector(
                              onTap: () {
                                AppHaptics.light();
                                _searchController.text = tag;
                                setState(() => _query = tag);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: GlassDecorations.glassCard(borderRadius: 12),
                                child: Text(
                                  '#$tag',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryGlow),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                  );
                },
              ),

              // Results
              FutureBuilder<List<Entry>>(
                future: _query.isNotEmpty ? vm.search(_query) : Future.value([]),
                builder: (context, snapshot) {
                  final results = snapshot.data ?? [];

                  if (_query.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      alignment: Alignment.center,
                      child: const Text(
                        'Type to search across titles, tags, drivers, and notes.',
                        style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                      ),
                    );
                  }

                  if (results.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      alignment: Alignment.center,
                      child: Text(
                        'No matches found for "$_query"',
                        style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                      ),
                    );
                  }

                  return Column(
                    children: [
                      for (final e in results) ...[
                        SwipeableEntryCard(
                          entry: e,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => EntryDetailScreen(entryId: e.id)),
                            );
                          },
                          onEdit: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => EntryDetailScreen(entryId: e.id)),
                            );
                          },
                          onDelete: () async {
                            await vm.deleteEntry(e.id);
                          },
                        ),
                        const SizedBox(height: 8),
                      ],
                    ],
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
