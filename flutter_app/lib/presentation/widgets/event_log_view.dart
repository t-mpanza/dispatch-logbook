import 'dart:async';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
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

  Widget _buildTripGroupRow(List<Trip> tripsInGroup) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: tripsInGroup.map((trip) => _buildTripBadge(trip)).toList(),
      ),
    );
  }

  Widget _buildTripBadge(Trip trip) {
    final isScanned = trip.count > 0;
    final isSlipPhoto = trip.note?.startsWith('slip:photo:') ?? false;
    final slipText = trip.note?.startsWith('slip:text:') == true
        ? trip.note!.substring(10)
        : '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isScanned
            ? AppColors.primary.withValues(alpha: 0.15)
            : AppColors.warning.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isScanned
              ? AppColors.primaryGlow.withValues(alpha: 0.4)
              : AppColors.warning.withValues(alpha: 0.4),
          width: 1,
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

  Widget _buildPhotoThumbnail(Attachment att) {
    if (att.bytes != null && att.bytes!.isNotEmpty) {
      return Image.memory(att.bytes!, width: 44, height: 44, fit: BoxFit.cover);
    }
    if (att.localFilePath != null) {
      final file = File(att.localFilePath!);
      if (file.existsSync()) {
        return Image.file(file, width: 44, height: 44, fit: BoxFit.cover);
      }
    }
    if (att.downloadUrl != null && att.downloadUrl!.isNotEmpty) {
      return Image.network(
        att.downloadUrl!,
        width: 44,
        height: 44,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          width: 44,
          height: 44,
          color: AppColors.glassSurfaceElevated,
          child: const Icon(Icons.image_outlined, size: 20, color: AppColors.textMuted),
        ),
      );
    }

    return Container(
      width: 44,
      height: 44,
      color: AppColors.glassSurfaceElevated,
      child: const Icon(Icons.image_rounded, color: AppColors.textMuted),
    );
  }

  Widget _buildAttachmentRow(Attachment att) {
    final isAudio = att.kind == AttachmentKind.audio;
    final isPhoto = att.kind == AttachmentKind.photo || att.kind == AttachmentKind.image;

    if (isAudio && audioService != null) {
      return _VoiceNotePlayerCard(
        attachment: att,
        audioService: audioService!,
        onDelete: () => onRemoveAttachment(att.id),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: GlassDecorations.glassCard(borderRadius: 16),
      child: Row(
        children: [
          if (isPhoto) ...[
            GestureDetector(
              onTap: () {
                AppHaptics.light();
                onOpenPhoto(att);
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: _buildPhotoThumbnail(att),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: GestureDetector(
                onTap: () {
                  AppHaptics.light();
                  onOpenPhoto(att);
                },
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

class _VoiceNotePlayerCard extends StatefulWidget {
  final Attachment attachment;
  final AudioService audioService;
  final VoidCallback onDelete;

  const _VoiceNotePlayerCard({
    required this.attachment,
    required this.audioService,
    required this.onDelete,
  });

  @override
  State<_VoiceNotePlayerCard> createState() => _VoiceNotePlayerCardState();
}

class _VoiceNotePlayerCardState extends State<_VoiceNotePlayerCard> {
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isPlaying = false;
  double _playbackSpeed = 1.0;

  StreamSubscription? _posSub;
  StreamSubscription? _durSub;
  StreamSubscription? _stateSub;

  @override
  void initState() {
    super.initState();
    final defaultDurMs = widget.attachment.durationMs ?? 0;
    _duration = Duration(milliseconds: defaultDurMs);

    _posSub = widget.audioService.onPositionChanged.listen((p) {
      if (mounted && widget.audioService.currentlyPlayingId == widget.attachment.id) {
        setState(() => _position = p);
      }
    });

    _durSub = widget.audioService.onDurationChanged.listen((d) {
      if (mounted && widget.audioService.currentlyPlayingId == widget.attachment.id) {
        setState(() => _duration = d);
      }
    });

    _stateSub = widget.audioService.onPlayerStateChanged.listen((s) {
      if (mounted) {
        final isThisPlaying = s == PlayerState.playing &&
            widget.audioService.currentlyPlayingId == widget.attachment.id;
        setState(() => _isPlaying = isThisPlaying);
      }
    });
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _durSub?.cancel();
    _stateSub?.cancel();
    super.dispose();
  }

  void _togglePlay() async {
    AppHaptics.light();
    if (_isPlaying) {
      await widget.audioService.pauseAudio();
    } else {
      await widget.audioService.playAttachment(widget.attachment);
    }
  }

  void _skip(int seconds) {
    AppHaptics.light();
    final targetSec = (_position.inSeconds + seconds).clamp(0, _duration.inSeconds);
    widget.audioService.seekAudio(Duration(seconds: targetSec));
  }

  void _cycleSpeed() {
    AppHaptics.light();
    final nextSpeed = _playbackSpeed == 1.0
        ? 1.25
        : (_playbackSpeed == 1.25 ? 1.5 : (_playbackSpeed == 1.5 ? 2.0 : 1.0));
    setState(() => _playbackSpeed = nextSpeed);
    widget.audioService.setPlaybackRate(nextSpeed);
  }

  String _formatDuration(Duration d) {
    final mins = d.inMinutes;
    final secs = d.inSeconds % 60;
    return '$mins:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final maxSec = _duration.inMilliseconds > 0 ? _duration.inMilliseconds.toDouble() : 1.0;
    final curSec = _position.inMilliseconds.toDouble().clamp(0.0, maxSec);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: GlassDecorations.glassElevated(borderRadius: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Icon, Title, Speed Selector, Delete
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.presetNlh.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.mic_rounded, color: AppColors.presetNlh, size: 16),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.attachment.name ?? 'Voice Note',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                    Text(
                      AppFormatters.formatTimeHHmm(widget.attachment.createdAt),
                      style: const TextStyle(fontSize: 9, color: AppColors.textMuted, fontFamily: 'monospace'),
                    ),
                  ],
                ),
              ),
              // Speed Multiplier Pill
              GestureDetector(
                onTap: _cycleSpeed,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.glassSurfaceElevated,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.glassBorder),
                  ),
                  child: Text(
                    '${_playbackSpeed}x',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryGlow,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, size: 16, color: AppColors.textMuted),
                onPressed: () {
                  AppHaptics.light();
                  widget.onDelete();
                },
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Interactive Scrubber Bar
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
              activeTrackColor: AppColors.primaryGlow,
              inactiveTrackColor: Colors.white.withValues(alpha: 0.1),
              thumbColor: Colors.white,
            ),
            child: Slider(
              value: curSec,
              min: 0.0,
              max: maxSec,
              onChanged: (val) {
                widget.audioService.seekAudio(Duration(milliseconds: val.toInt()));
              },
            ),
          ),

          // Controls Row: Play/Pause, -5s, +5s, Duration Timers
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                GestureDetector(
                  onTap: _togglePlay,
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.replay_5_rounded, size: 20, color: AppColors.textSecondary),
                  onPressed: () => _skip(-5),
                ),
                IconButton(
                  icon: const Icon(Icons.forward_5_rounded, size: 20, color: AppColors.textSecondary),
                  onPressed: () => _skip(5),
                ),
                const Spacer(),
                Text(
                  '${_formatDuration(_position)} / ${_formatDuration(_duration)}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textMuted,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
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
