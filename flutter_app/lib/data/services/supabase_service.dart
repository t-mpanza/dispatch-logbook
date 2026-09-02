import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/supabase_constants.dart';
import '../models/entry.dart';
import '../models/attachment.dart';
import '../models/note_block.dart';
import '../models/loading_sheet_trip.dart';
import '../models/trip.dart';
import 'database_service.dart';

class SupabaseService {
  static SupabaseClient? _client;
  static String? _cachedUserId;
  static RealtimeChannel? _realtimeChannel;

  static SupabaseClient get client {
    _client ??= Supabase.instance.client;
    return _client!;
  }

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: SupabaseConstants.url,
      // ignore: deprecated_member_use
      anonKey: SupabaseConstants.anonKey,
    );
    _client = Supabase.instance.client;

    // Attempt to ensure attachments bucket exists
    try {
      await _client!.storage.createBucket(
        SupabaseConstants.attachmentsBucket,
        const BucketOptions(public: true),
      );
    } catch (_) {}
  }

  static Future<String?> getUserId() async {
    if (_cachedUserId != null) return _cachedUserId;

    try {
      final user = client.auth.currentUser;
      if (user != null) {
        _cachedUserId = user.id;
        return _cachedUserId;
      }

      // Auto-authenticate with operational master account
      final res = await client.auth.signInWithPassword(
        email: SupabaseConstants.masterEmail,
        password: SupabaseConstants.masterPassword,
      );

      _cachedUserId = res.user?.id;
      return _cachedUserId;
    } catch (e) {
      debugPrint('Supabase auth error: $e');
      return null;
    }
  }

  // ── Push Engine (Batch Upsert) ──────────────────────────────────────────────

  /// Build the wire payload for an entry. Exposed (instead of private) so the
  /// tombstone-omit invariant is unit-testable.
  static Map<String, dynamic> formatEntryPayload(Entry entry, String userId) {
    final cleanNotes =
        entry.notes.where((n) => n.id != '__meta_sheet__').toList();
    final hasMeta = (entry.loadingSheetTrips != null &&
            entry.loadingSheetTrips!.isNotEmpty) ||
        entry.despatcherName != null;

    final notesPayload = hasMeta
        ? [
            ...cleanNotes.map((n) => n.toMap()),
            {
              'id': '__meta_sheet__',
              'text': jsonEncode({
                'loadingSheetTrips':
                    entry.loadingSheetTrips?.map((t) => t.toMap()).toList() ?? [],
                'despatcherName': entry.despatcherName ?? 'Theolus',
              }),
              'createdAt': entry.updatedAt,
            }
          ]
        : cleanNotes.map((n) => n.toMap()).toList();

    final payload = <String, dynamic>{
      'id': entry.id,
      'user_id': userId,
      'title': entry.title,
      'tags': entry.tags,
      'notes': notesPayload,
      'trips': entry.trips?.map((t) => t.toMap()).toList(),
      'expected_total': entry.expectedTotal,
      'day_key': entry.dayKey,
      'month_key': entry.monthKey,
      'year_key': entry.yearKey,
      'created_at': entry.createdAt,
      'updated_at': entry.updatedAt,
    };

    // Omit deleted_at for live rows: a stale offline device re-pushing its
    // live copy must never clear an existing tombstone via upsert.
    // Tombstoned rows always carry their deleted_at.
    if (entry.deletedAt != null) {
      payload['deleted_at'] = entry.deletedAt;
    }

    return payload;
  }

  static Future<bool> pushEntriesBatch(List<Entry> entries) async {
    if (entries.isEmpty) return true;

    final userId = await getUserId();
    if (userId == null) return false;

    try {
      final payloads =
          entries.map((e) => formatEntryPayload(e, userId)).toList();

      for (var i = 0; i < payloads.length; i += 50) {
        final chunk = payloads.sublist(
          i,
          (i + 50 > payloads.length) ? payloads.length : i + 50,
        );
        await client.from('entries').upsert(chunk, onConflict: 'id');
      }

      // Background upload of media attachments
      for (final entry in entries) {
        for (final att in entry.attachments) {
          if (att.bytes != null && att.storagePath == null) {
            _uploadAttachment(userId, entry.id, att);
          }
        }
      }

      return true;
    } catch (e) {
      debugPrint('Supabase push batch error: $e');
      return false;
    }
  }

  /// Push local soft-delete tombstones to the cloud so deletions made while
  /// offline still propagate to every other device.
  static Future<void> pushTombstones() async {
    try {
      final tombstones = await DatabaseService.getAllTombstonedEntries();
      if (tombstones.isEmpty) return;

      final userId = await getUserId();
      if (userId == null) return;

      final payloads =
          tombstones.map((e) => formatEntryPayload(e, userId)).toList();
      for (var i = 0; i < payloads.length; i += 50) {
        final chunk = payloads.sublist(
          i,
          (i + 50 > payloads.length) ? payloads.length : i + 50,
        );
        await client.from('entries').upsert(chunk, onConflict: 'id');
      }
    } catch (e) {
      debugPrint('Supabase tombstone push error: $e');
    }
  }

  static Future<void> _uploadAttachment(
    String userId,
    String entryId,
    Attachment att,
  ) async {
    if (att.bytes == null) return;
    final ext = att.mime.split('/').length > 1
        ? att.mime.split('/')[1].split(';')[0]
        : 'bin';
    final path = '$userId/${att.id}.$ext';

    try {
      await client.storage.from(SupabaseConstants.attachmentsBucket).uploadBinary(
            path,
            att.bytes!,
            fileOptions: FileOptions(contentType: att.mime, upsert: true),
          );

      await client.from('entry_attachments').upsert({
        'id': att.id,
        'entry_id': entryId,
        'user_id': userId,
        'kind': att.kind.name,
        'mime': att.mime,
        'name': att.name,
        'caption': att.caption,
        'duration_ms': att.durationMs,
        'width': att.width,
        'height': att.height,
        'storage_path': path,
        'created_at': att.createdAt,
      }, onConflict: 'id');
    } catch (e) {
      debugPrint('Attachment upload error: $e');
    }
  }

  // ── Pull Engine ─────────────────────────────────────────────────────────────

  static Future<bool> pullAndMerge() async {
    final userId = await getUserId();
    if (userId == null) return false;

    try {
      final entriesRes = await client
          .from('entries')
          .select('*')
          .eq('user_id', userId)
          .order('updated_at', ascending: false)
          .limit(200);

      final attsRes = await client
          .from('entry_attachments')
          .select('*')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(300);

      final remoteEntries = List<Map<String, dynamic>>.from(entriesRes);
      final remoteAtts = List<Map<String, dynamic>>.from(attsRes);

      final Map<String, List<Map<String, dynamic>>> attsByEntryId = {};
      for (final att in remoteAtts) {
        final entryId = att['entry_id'] as String?;
        if (entryId != null) {
          attsByEntryId.putIfAbsent(entryId, () => []).add(att);
        }
      }

      final localEntries = await DatabaseService.getAllEntriesIncludingDeleted();
      final localMap = {for (final e in localEntries) e.id: e};
      final List<Entry> toUpdate = [];
      final List<String> tombstoneIds = [];

      for (final remote in remoteEntries) {
        final id = remote['id'] as String;
        final local = localMap[id];

        // ── Tombstone propagation ──────────────────────────────────────────
        // A remote tombstone always wins: soft-delete the local copy.
        final remoteDeletedAt = (remote['deleted_at'] as num?)?.toInt();
        if (remoteDeletedAt != null) {
          if (local != null && local.deletedAt == null) {
            tombstoneIds.add(id);
          }
          continue;
        }
        // A local tombstone must never be resurrected by a stale remote copy.
        if (local != null && local.deletedAt != null) {
          continue;
        }

        final remoteUpdatedAt =
            (remote['updated_at'] as num?)?.toInt() ?? 0;

        final isNewer = local == null || remoteUpdatedAt > local.updatedAt;
        if (!isNewer) continue;

        // Parse meta notes
        List<LoadingSheetTrip>? loadingTrips;
        String? despatcherName;
        final List<NoteBlock> userNotes = [];

        final rawNotes = remote['notes'];
        if (rawNotes is List) {
          for (final n in rawNotes) {
            if (n is Map) {
              if (n['id'] == '__meta_sheet__') {
                try {
                  final parsed = jsonDecode(n['text'] as String);
                  if (parsed is Map) {
                    if (parsed['loadingSheetTrips'] is List) {
                      loadingTrips = (parsed['loadingSheetTrips'] as List)
                          .map((t) => LoadingSheetTrip.fromMap(
                              Map<String, dynamic>.from(t)))
                          .toList();
                    }
                    if (parsed['despatcherName'] is String) {
                      despatcherName = parsed['despatcherName'] as String;
                    }
                  }
                } catch (_) {}
              } else {
                userNotes.add(NoteBlock.fromMap(Map<String, dynamic>.from(n)));
              }
            }
          }
        }

        // Map attachments, preserving local file paths and bytes
        final localAttMap = {for (final a in (local?.attachments ?? [])) a.id: a};

        final attList = attsByEntryId[id] ?? [];
        final List<Attachment> attachments = attList.map((a) {
          final attId = a['id'] as String;
          final localAtt = localAttMap[attId];
          final sPath = a['storage_path'] as String?;
          final directUrl = a['download_url'] as String?;
          final resolvedUrl = directUrl ??
              (sPath != null
                  ? client.storage.from('attachments').getPublicUrl(sPath)
                  : null);

          return Attachment(
            id: attId,
            kind: AttachmentKind.values.firstWhere(
              (k) => k.name == (a['kind'] as String? ?? 'file'),
              orElse: () => AttachmentKind.file,
            ),
            bytes: localAtt?.bytes,
            mime: a['mime'] as String? ?? 'application/octet-stream',
            name: a['name'] as String? ?? localAtt?.name,
            caption: a['caption'] as String? ?? localAtt?.caption,
            durationMs: (a['duration_ms'] as num?)?.toInt() ?? localAtt?.durationMs,
            width: (a['width'] as num?)?.toInt() ?? localAtt?.width,
            height: (a['height'] as num?)?.toInt() ?? localAtt?.height,
            storagePath: sPath ?? localAtt?.storagePath,
            downloadUrl: resolvedUrl ?? localAtt?.downloadUrl,
            localFilePath: localAtt?.localFilePath,
            createdAt: (a['created_at'] as num?)?.toInt() ?? localAtt?.createdAt ?? 0,
          );
        }).toList();

        // Also preserve any newly captured local attachments not yet in remote
        for (final localAtt in (local?.attachments ?? [])) {
          if (!attachments.any((a) => a.id == localAtt.id)) {
            attachments.add(localAtt);
          }
        }

        // Parse trips
        List<Trip>? trips;
        if (remote['trips'] is List) {
          trips = (remote['trips'] as List)
              .map((t) => Trip.fromMap(Map<String, dynamic>.from(t)))
              .toList();
        }

        List<String> tags = [];
        if (remote['tags'] is List) {
          tags = (remote['tags'] as List).map((e) => e.toString()).toList();
        }

        final merged = Entry(
          id: id,
          title: remote['title'] as String? ?? 'Untitled',
          tags: tags,
          expectedTotal: (remote['expected_total'] as num?)?.toInt(),
          notes: userNotes,
          attachments: attachments,
          trips: trips,
          loadingSheetTrips: loadingTrips ?? local?.loadingSheetTrips,
          despatcherName: despatcherName ?? local?.despatcherName,
          createdAt: (remote['created_at'] as num?)?.toInt() ?? 0,
          updatedAt: remoteUpdatedAt,
          dayKey: remote['day_key'] as String? ?? '',
          monthKey: remote['month_key'] as String? ?? '',
          yearKey: remote['year_key'] as String? ?? '',
        );

        toUpdate.add(merged);
      }

      if (toUpdate.isNotEmpty) {
        await DatabaseService.insertOrUpdateBatch(toUpdate);
      }

      for (final id in tombstoneIds) {
        await DatabaseService.softDeleteEntry(id);
      }

      return true;
    } catch (e) {
      debugPrint('Supabase pull error: $e');
      return false;
    }
  }

  // ── Realtime & Broadcast ────────────────────────────────────────────────────

  static void setupRealtimeSync(VoidCallback onEntryChanged) {
    try {
      _realtimeChannel = client.channel('dispatch_live_sync');
      _realtimeChannel!.onBroadcast(
        event: 'entry_changed',
        callback: (payload) async {
          await pullAndMerge();
          onEntryChanged();
        },
      ).subscribe();
    } catch (e) {
      debugPrint('Realtime channel setup error: $e');
    }
  }

  static void broadcastEntryChange(String entryId) {
    try {
      _realtimeChannel?.sendBroadcastMessage(
        event: 'entry_changed',
        payload: {
          'entryId': entryId,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        },
      );
    } catch (e) {
      debugPrint('Broadcast error: $e');
    }
  }

  static Future<bool> deleteRemoteEntry(String entryId) async {
    final userId = await getUserId();
    if (userId == null) return false;

    try {
      // Soft-delete on the server (tombstone) instead of a hard delete so
      // offline devices converge on the deletion instead of re-pushing a
      // stale copy.
      await client
          .from('entries')
          .update({'deleted_at': DateTime.now().millisecondsSinceEpoch})
          .eq('id', entryId)
          .eq('user_id', userId);

      broadcastEntryChange(entryId);
      return true;
    } catch (e) {
      debugPrint('Supabase delete error: $e');
      return false;
    }
  }
}
