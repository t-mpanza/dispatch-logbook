import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/glass_decorations.dart';
import '../../core/utils/haptics.dart';
import '../../data/models/ibt_manifest.dart';
import '../../data/services/appsync_manifest_service.dart';
import 'aws_auth_dialog.dart';

/// Unified "Add IBT" control.
///
/// - Numeric-only keyboard with an integrated suffix search icon.
/// - Intelligent batch extraction: paste `119512, 119513  119514` and every
///   document number is parsed and fetched in a single pass.
/// - Parallel fetch with per-document failure isolation and live progress.
class IbtPicker extends StatefulWidget {
  final List<IbtDocument> documents;
  final ValueChanged<List<IbtDocument>> onChanged;
  final String hintText;

  const IbtPicker({
    super.key,
    required this.documents,
    required this.onChanged,
    this.hintText = 'Add IBT numbers… e.g. 119512, 119513',
  });

  @override
  State<IbtPicker> createState() => _IbtPickerState();
}

class _IbtPickerState extends State<IbtPicker> {
  final TextEditingController _controller = TextEditingController();
  final Set<String> _pending = <String>{};
  final Map<String, String> _failures = <String, String>{};
  String? _lastSuccessMessage;

  static final RegExp _docNumberRegex = RegExp(r'\d+');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<String> _extractDocNumbers(String raw) {
    final matches = _docNumberRegex.allMatches(raw);
    final numbers = matches.map((m) => m.group(0)!).toList();
    return numbers.isEmpty ? [raw.trim()] : numbers;
  }

  Future<void> _fetchBatch() async {
    final raw = _controller.text.trim();
    if (raw.isEmpty) return;

    final docNumbers = _extractDocNumbers(raw);
    AppHaptics.light();

    final existing =
        widget.documents.map((d) => d.documentNo.toUpperCase()).toSet();
    final failures = <String, String>{};

    setState(() {
      _pending.addAll(
        docNumbers.where((n) => !existing.contains(_prefixIbt(n))),
      );
      _failures.clear();
      _lastSuccessMessage = null;
    });

    final results = await Future.wait(
      [for (final docNo in docNumbers) _fetchOne(docNo, failures)],
    );

    if (!mounted) return;

    final fetched = results.whereType<IbtDocument>().toList();

    if (fetched.isNotEmpty) {
      final merged = <IbtDocument>[...widget.documents];
      for (final doc in fetched) {
        final idx = merged.indexWhere(
          (d) => d.documentNo.toUpperCase() == doc.documentNo.toUpperCase(),
        );
        if (idx >= 0) {
          merged[idx] = doc;
        } else {
          merged.add(doc);
        }
      }
      widget.onChanged(merged);
      AppHaptics.success();
      setState(() {
        _lastSuccessMessage = fetched.length == 1
            ? 'IBT ${fetched.first.documentNo} attached'
            : '${fetched.length} IBT documents attached';
        _controller.clear();
      });
    }

    if (failures.isNotEmpty) {
      AppHaptics.error();
      setState(() => _failures.addAll(failures));
      final firstFailure = failures.values.first;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(firstFailure),
          backgroundColor: Colors.redAccent,
          action: SnackBarAction(
            label: 'AWS Login',
            textColor: Colors.white,
            onPressed: () => AwsAuthDialog.show(context),
          ),
        ),
      );
    }
  }

  String _prefixIbt(String raw) {
    final trimmed = raw.trim().toUpperCase();
    if (trimmed.startsWith('IBT')) return trimmed;
    return 'IBT$trimmed';
  }

  Future<IbtDocument?> _fetchOne(
    String docNo,
    Map<String, String> failures,
  ) async {
    try {
      final doc = await AppSyncManifestService.fetchIbtDocument(docNo);
      AppHaptics.medium();
      if (mounted) {
        setState(() => _pending.remove(docNo));
      }
      return doc;
    } catch (e) {
      if (mounted) {
        setState(() => _pending.remove(docNo));
      }
      failures[docNo] = 'IBT $docNo failed: ${_formatError(e)}';
      return null;
    }
  }

  String _formatError(Object e) {
    final s = e.toString().replaceAll('Exception: ', '');
    return s.length > 90 ? '${s.substring(0, 90)}…' : s;
  }

  @override
  Widget build(BuildContext context) {
    final isLight = AppColors.isLight(context);
    final accent = isLight ? AppColors.primary : AppColors.primaryGlow;
    final isBusy = _pending.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Unified input with integrated suffix icon
        Container(
          decoration: GlassDecorations.glassCard(context: context, borderRadius: 14),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9,\s]')),
                  ],
                  textInputAction: TextInputAction.search,
                  style: TextStyle(
                    color: AppColors.dynamicTextPrimary(context),
                    fontSize: 13,
                    fontFamily: 'monospace',
                    letterSpacing: 1.2,
                  ),
                  decoration: InputDecoration(
                    hintText: widget.hintText,
                    hintStyle: TextStyle(
                      color: AppColors.dynamicTextMuted(context),
                      fontSize: 12,
                      letterSpacing: 0,
                    ),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 13,
                    ),
                    border: InputBorder.none,
                  ),
                  onSubmitted: (_) => _fetchBatch(),
                ),
              ),
              if (isBusy)
                Padding(
                  padding: const EdgeInsets.only(right: 14),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: accent,
                    ),
                  ),
                )
              else
                IconButton(
                  onPressed: _fetchBatch,
                  icon: Icon(Icons.search_rounded, color: accent, size: 20),
                  tooltip: 'Fetch IBT',
                ),
            ],
          ),
        ),

        if (_lastSuccessMessage != null) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.check_circle_rounded, size: 13, color: AppColors.success),
              const SizedBox(width: 5),
              Text(
                _lastSuccessMessage!,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppColors.success,
                ),
              ),
            ],
          ),
        ],

        for (final failure in _failures.values) ...[
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.error_outline_rounded, size: 13, color: AppColors.error),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  failure,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.error,
                  ),
                ),
              ),
            ],
          ),
        ],

        if (widget.documents.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: widget.documents.map((doc) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: isLight ? 0.1 : 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: accent.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.receipt_long_rounded, size: 12, color: accent),
                    const SizedBox(width: 6),
                    Text(
                      '${doc.documentNo} (${doc.total} tyres • ${doc.lineItems.length} lines)',
                      style: TextStyle(
                        color: AppColors.dynamicTextPrimary(context),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 6),
                    InkWell(
                      onTap: () {
                        AppHaptics.light();
                        final updated = [...widget.documents]
                          ..removeWhere(
                            (d) =>
                                d.documentNo.toUpperCase() ==
                                doc.documentNo.toUpperCase(),
                          );
                        widget.onChanged(updated);
                      },
                      child: Icon(
                        Icons.close,
                        size: 14,
                        color: AppColors.dynamicTextMuted(context),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
}
