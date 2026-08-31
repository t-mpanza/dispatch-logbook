import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/glass_decorations.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/haptics.dart';
import '../../data/models/attachment.dart';
import '../../data/models/note_block.dart';
import '../../data/models/trip.dart';
import '../../data/services/audio_service.dart';

class EventLogView extends StatelessWidget {
  final List<NoteBlock> notes;
  final List<Attachment> attachments;
  final List<Trip> trips;
  final Function(String) onRemoveNote;
  final Function(String) onRemoveAttachment;
  final Function(String) onRemoveTrip;
  final Function(Attachment) onOpenPhoto;
  final AudioService? audioService;

  const EventLogView({
    super.key,
    required this.notes,
    required this.attachments,
    required this.trips,
    required this.onRemoveNote,
    required this.onRemoveAttachment,
    required this.onRemoveTrip,
    required this.onOpenPhoto,
    this.audioService,
  });

  @override
  Widget build(BuildContext context) {
    final cleanNotes = notes
        .where((n) =>
            n.id != '__meta_sheet__' &&
            !n.text.startsWith('{"loadingSheetTrips"') &&
            !n.text.startsWith('{"despatcherName"'))
        .toList();

    // Group items chronologically
    final List<_LogItem> raw = [
      ...cleanNotes.map((n) => _LogItem(type: _ItemType.note, at: n.createdAt, note: n)),
      ...attachments.map((a) => _LogItem(type: _ItemType.att, at: a.createdAt, attachment: a)),
      ...trips.map((t) => _LogItem(type: _ItemType.trip, at: t.createdAt, trip: t)),
    ]..sort((a, b) => a.at.compareTo(b.at));

    if (raw.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 32),
        alignment: Alignment.center,
        child: const Text(
          'Nothing logged yet. Use the action bar below to add notes, photos or voice.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textMuted,
            fontFamily: 'monospace',
          ),
        ),
      );
    }

    final List<_RenderGroup> groups = [];
    for (final item in raw) {
      if (item.type == _ItemType.trip) {
        if (groups.isNotEmpty && groups.last.type == _GroupType.tripGroup) {
          groups.last.trips.add(item.trip!);
        } else {
          groups.add(_RenderGroup(
            type: _GroupType.tripGroup,
            at: item.at,
            trips: [item.trip!],
          ));
        }
      } else if (item.type == _ItemType.note) {
        groups.add(_RenderGroup(type: _GroupType.note, at: item.at, note: item.note));
      } else {
        groups.add(_RenderGroup(type: _GroupType.att, at: item.at, attachment: item.attachment));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final group in groups) _buildGroupWidget(group),
      ],
    );
  }

  Widget _buildGroupWidget(_RenderGroup group) {
    switch (group.type) {
      case _GroupType.tripGroup:
        return _buildTripGroupRow(group.trips);
      case _GroupType.note:
        return _buildNoteRow(group.note!);
      case _GroupType.att:
        return _buildAttachmentRow(group.attachment!);
    }
  }

  Widget _buildTripGroupRow(List<Trip> trips) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (var i = 0; i < trips.length; i++) ...[
            if (i > 0)
              const Text('─', style: TextStyle(color: Color(0xFF334155), fontSize: 10)),
            _buildTripChip(trips[i]),
          ],
        ],
      ),
    );
  }

  Widget _buildTripChip(Trip trip) {
    final isScanned = trip.count > 0;
    final note = trip.note ?? '';
    final isSlipPhoto = note.startsWith('slip:photo:');
    final slipText = note.startsWith('slip:text:') ? note.substring(10) : note;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isScanned
            ? AppColors.primary.withValues(alpha: 0.15)
            : AppColors.warning.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isScanned
              ? AppColors.primaryGlow.withValues(alpha: 0.3)
              : AppColors.warning.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            isScanned ? '+${trip.count}' : '+${trip.rejected}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: isScanned ? AppColors.primaryGlow : AppColors.warning,
              fontFamily: 'monospace',
            ),
          ),
          if (isSlipPhoto) ...[
            const SizedBox(width: 4),
            const Text('📷', style: TextStyle(fontSize: 10)),
          ],
          if (slipText.isNotEmpty && !isSlipPhoto) ...[
            const SizedBox(width: 4),
            Text(
              slipText,
              style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
            ),
          ],
          const SizedBox(width: 4),
          Text(
            AppFormatters.formatTimeHHmm(trip.createdAt),
            style: const TextStyle(
              fontSize: 9,
              color: AppColors.textMuted,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(width: 2),
          GestureDetector(
            onTap: () {
              AppHaptics.light();
              onRemoveTrip(trip.id);
            },
            child: const Padding(
              padding: EdgeInsets.only(left: 2),
              child: Icon(Icons.close_rounded, size: 12, color: AppColors.textMuted),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoteRow(NoteBlock note) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: GlassDecorations.glassCard(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: 16,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              note.text,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textPrimary,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                AppFormatters.formatTimeHHmm(note.createdAt),
                style: const TextStyle(fontSize: 9, color: AppColors.textMuted, fontFamily: 'monospace'),
              ),
              const SizedBox(height: 4),
              GestureDetector(
                onTap: () {
                  AppHaptics.light();
                  onRemoveNote(note.id);
                },
                child: const Icon(Icons.delete_outline_rounded, size: 16, color: AppColors.textMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAttachmentRow(Attachment att) {
    final isAudio = att.kind == AttachmentKind.audio;
    final isPhoto = att.kind == AttachmentKind.photo || att.kind == AttachmentKind.image;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: GlassDecorations.glassCard(borderRadius: 16),
      child: Row(
        children: [
          if (isAudio) ...[
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.presetNlh.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.mic_rounded, color: AppColors.presetNlh, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    att.name ?? 'Voice Note',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  Text(
                    att.durationMs != null ? '${(att.durationMs! / 1000).toStringAsFixed(1)}s' : 'Audio recording',
                    style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.play_arrow_rounded, color: AppColors.primaryGlow),
              onPressed: () {
                AppHaptics.light();
                if (att.bytes != null && audioService != null) {
                  audioService!.playBytes(att.bytes!);
                } else if (att.localFilePath != null && audioService != null) {
                  audioService!.playAudio(att.localFilePath!);
                } else if (att.downloadUrl != null && audioService != null) {
                  audioService!.playAudio(att.downloadUrl!);
                }
              },
            ),
          ] else if (isPhoto) ...[
            GestureDetector(
              onTap: () {
                AppHaptics.light();
                onOpenPhoto(att);
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: att.bytes != null
                    ? Image.memory(att.bytes!, width: 44, height: 44, fit: BoxFit.cover)
                    : Container(
                        width: 44,
                        height: 44,
                        color: AppColors.glassSurfaceElevated,
                        child: const Icon(Icons.image, color: AppColors.textMuted),
                      ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    att.name ?? 'Photo Attachment',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  Text(
                    AppFormatters.formatTimeHHmm(att.createdAt),
                    style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
          ],
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, size: 16, color: AppColors.textMuted),
            onPressed: () {
              AppHaptics.light();
              onRemoveAttachment(att.id);
            },
          ),
        ],
      ),
    );
  }
}

enum _ItemType { note, att, trip }
enum _GroupType { note, att, tripGroup }

class _LogItem {
  final _ItemType type;
  final int at;
  final NoteBlock? note;
  final Attachment? attachment;
  final Trip? trip;

  _LogItem({required this.type, required this.at, this.note, this.attachment, this.trip});
}

class _RenderGroup {
  final _GroupType type;
  final int at;
  final NoteBlock? note;
  final Attachment? attachment;
  final List<Trip> trips;

  _RenderGroup({required this.type, required this.at, this.note, this.attachment, this.trips = const []});
}
