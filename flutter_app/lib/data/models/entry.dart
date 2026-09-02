import 'dart:convert';
import 'note_block.dart';
import 'attachment.dart';
import 'trip.dart';
import 'loading_sheet_trip.dart';

class Entry {
  final String id;
  final String title;
  final List<String> tags;
  final int? expectedTotal;
  final List<NoteBlock> notes;
  final List<Attachment> attachments;
  final List<Trip>? trips;
  final List<LoadingSheetTrip>? loadingSheetTrips;
  final String? despatcherName;
  final int createdAt;
  final int updatedAt;
  final String dayKey;
  final String monthKey;
  final String yearKey;
  final int? deletedAt;

  const Entry({
    required this.id,
    required this.title,
    required this.tags,
    this.expectedTotal,
    required this.notes,
    required this.attachments,
    this.trips,
    this.loadingSheetTrips,
    this.despatcherName,
    required this.createdAt,
    required this.updatedAt,
    required this.dayKey,
    required this.monthKey,
    required this.yearKey,
    this.deletedAt,
  });

  Entry copyWith({
    String? id,
    String? title,
    List<String>? tags,
    int? expectedTotal,
    List<NoteBlock>? notes,
    List<Attachment>? attachments,
    List<Trip>? trips,
    List<LoadingSheetTrip>? loadingSheetTrips,
    String? despatcherName,
    int? createdAt,
    int? updatedAt,
    String? dayKey,
    String? monthKey,
    String? yearKey,
    int? deletedAt,
  }) {
    return Entry(
      id: id ?? this.id,
      title: title ?? this.title,
      tags: tags ?? this.tags,
      expectedTotal: expectedTotal ?? this.expectedTotal,
      notes: notes ?? this.notes,
      attachments: attachments ?? this.attachments,
      trips: trips ?? this.trips,
      loadingSheetTrips: loadingSheetTrips ?? this.loadingSheetTrips,
      despatcherName: despatcherName ?? this.despatcherName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      dayKey: dayKey ?? this.dayKey,
      monthKey: monthKey ?? this.monthKey,
      yearKey: yearKey ?? this.yearKey,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'tags': jsonEncode(tags),
      'expected_total': expectedTotal,
      'notes': jsonEncode(notes.map((n) => n.toMap()).toList()),
      'attachments': jsonEncode(attachments.map((a) => a.toMap()).toList()),
      'trips': trips != null ? jsonEncode(trips!.map((t) => t.toMap()).toList()) : null,
      'loading_sheet_trips': loadingSheetTrips != null
          ? jsonEncode(loadingSheetTrips!.map((t) => t.toMap()).toList())
          : null,
      'despatcher_name': despatcherName,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'day_key': dayKey,
      'month_key': monthKey,
      'year_key': yearKey,
      'deleted_at': deletedAt,
    };
  }

  factory Entry.fromMap(Map<String, dynamic> map) {
    List<String> parsedTags = [];
    if (map['tags'] != null) {
      if (map['tags'] is String) {
        try {
          final decoded = jsonDecode(map['tags']);
          if (decoded is List) {
            parsedTags = decoded.map((e) => e.toString()).toList();
          }
        } catch (_) {}
      } else if (map['tags'] is List) {
        parsedTags = (map['tags'] as List).map((e) => e.toString()).toList();
      }
    }

    List<NoteBlock> parsedNotes = [];
    if (map['notes'] != null) {
      if (map['notes'] is String) {
        try {
          final decoded = jsonDecode(map['notes']);
          if (decoded is List) {
            parsedNotes = decoded
                .map((n) => NoteBlock.fromMap(Map<String, dynamic>.from(n)))
                .toList();
          }
        } catch (_) {}
      } else if (map['notes'] is List) {
        parsedNotes = (map['notes'] as List)
            .map((n) => NoteBlock.fromMap(Map<String, dynamic>.from(n)))
            .toList();
      }
    }

    List<Attachment> parsedAttachments = [];
    if (map['attachments'] != null) {
      if (map['attachments'] is String) {
        try {
          final decoded = jsonDecode(map['attachments']);
          if (decoded is List) {
            parsedAttachments = decoded
                .map((a) => Attachment.fromMap(Map<String, dynamic>.from(a)))
                .toList();
          }
        } catch (_) {}
      } else if (map['attachments'] is List) {
        parsedAttachments = (map['attachments'] as List)
            .map((a) => Attachment.fromMap(Map<String, dynamic>.from(a)))
            .toList();
      }
    }

    List<Trip>? parsedTrips;
    if (map['trips'] != null) {
      if (map['trips'] is String) {
        try {
          final decoded = jsonDecode(map['trips']);
          if (decoded is List) {
            parsedTrips = decoded
                .map((t) => Trip.fromMap(Map<String, dynamic>.from(t)))
                .toList();
          }
        } catch (_) {}
      } else if (map['trips'] is List) {
        parsedTrips = (map['trips'] as List)
            .map((t) => Trip.fromMap(Map<String, dynamic>.from(t)))
            .toList();
      }
    }

    List<LoadingSheetTrip>? parsedLoadingTrips;
    final loadingData = map['loading_sheet_trips'] ?? map['loadingSheetTrips'];
    if (loadingData != null) {
      if (loadingData is String) {
        try {
          final decoded = jsonDecode(loadingData);
          if (decoded is List) {
            parsedLoadingTrips = decoded
                .map((t) => LoadingSheetTrip.fromMap(Map<String, dynamic>.from(t)))
                .toList();
          }
        } catch (_) {}
      } else if (loadingData is List) {
        parsedLoadingTrips = loadingData
            .map((t) => LoadingSheetTrip.fromMap(Map<String, dynamic>.from(t)))
            .toList();
      }
    }

    return Entry(
      id: map['id'] as String,
      title: map['title'] as String? ?? 'Untitled',
      tags: parsedTags,
      expectedTotal: (map['expected_total'] as num?)?.toInt(),
      notes: parsedNotes,
      attachments: parsedAttachments,
      trips: parsedTrips,
      loadingSheetTrips: parsedLoadingTrips,
      despatcherName: map['despatcher_name'] as String?,
      createdAt: (map['created_at'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
      updatedAt: (map['updated_at'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
      dayKey: map['day_key'] as String? ?? '',
      monthKey: map['month_key'] as String? ?? '',
      yearKey: map['year_key'] as String? ?? '',
      deletedAt: (map['deleted_at'] as num?)?.toInt(),
    );
  }
}
