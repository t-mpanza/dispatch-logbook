import '../models/ibt_manifest.dart';
import '../models/staged_document.dart';
import '../repositories/staged_document_repository.dart';
import '../services/appsync_manifest_service.dart';
import '../services/database_service.dart';
import '../../dispatch/dispatch_api.dart';
import '../../dispatch/domain/document_number.dart';
import '../../dispatch/models/slip_tyre.dart';

/// Per-document outcome of a batch resolve — every document gets its own
/// verdict; one failure never kills the batch.
enum DocumentResolveStatus { ok, duplicate, notFound, error, unsupported }

class DocumentResolveResult {
  const DocumentResolveResult._({
    required this.input,
    this.stream,
    this.documentNo,
    required this.status,
    this.message,
    this.document,
  });

  final String input;
  final DocumentStream? stream;
  final String? documentNo;
  final DocumentResolveStatus status;
  final String? message;
  final StagedDocument? document;

  bool get isOk => status == DocumentResolveStatus.ok;
}

/// What a fetch yields — the common shape of every document stream.
class FetchedDocument {
  const FetchedDocument({
    this.customerName,
    this.customerCode,
    this.total,
    this.slips = const [],
    this.lineItems = const [],
  });

  final String? customerName;
  final String? customerCode;
  final int? total;
  final List<SlipTyre> slips;
  final List<IbtLineItem> lineItems;
}

typedef DocumentFetcher = Future<FetchedDocument> Function(
  DocumentStream stream,
  String documentNo,
);

/// One parsed staging token — [stream] is null for bare digits (probe).
class _Spec {
  const _Spec(this.stream, this.documentNo);

  final DocumentStream? stream;
  final String documentNo;
}

/// Stage ALL of a truck's documents at once, in PARALLEL (D16).
///
/// The operator pastes `INV2392908, DIBT0179154, IBT122773`; the resolver
/// classifies each by prefix (or the fallback chip), fetches every one
/// concurrently, caches the manifests locally (D15) and reports a verdict
/// per document — including duplicate refusal (D8) and not-found vs
/// connection errors, so the UI can show chips turning green or red.
class DocumentResolver {
  DocumentResolver({DocumentFetcher? fetcher, this._repository})
      : _fetcher = fetcher ?? defaultFetcher;

  final DocumentFetcher _fetcher;
  final StagedDocumentRepository? _repository;

  /// The production fetcher. AMS INV rides the `inv` key — the app-05
  /// quirk, CONFIRMED from the decoded loader.
  static Future<FetchedDocument> defaultFetcher(
    DocumentStream stream,
    String documentNo,
  ) async {
    switch (stream) {
      case DocumentStream.inv:
      case DocumentStream.amsInv:
        final block = await DispatchApi.fetchDeliveryDocument(inv: documentNo);
        return FetchedDocument(
          customerName: block.customerName,
          customerCode: block.customerCode,
          total: block.total,
          slips: block.slips,
        );
      case DocumentStream.dibt:
        final block = await DispatchApi.fetchDeliveryDocument(dibt: documentNo);
        return FetchedDocument(
          customerName: block.customerName,
          customerCode: block.customerCode,
          total: block.total,
          slips: block.slips,
        );
      case DocumentStream.ibt:
        final doc = await AppSyncManifestService.fetchIbtDocument(documentNo);
        return FetchedDocument(total: doc.total, lineItems: doc.lineItems);
      case DocumentStream.rejects:
        throw UnsupportedError('SCRAPS is a mode, not a document');
    }
  }

  Future<List<DocumentResolveResult>> resolveBatch({
    required String entryId,
    required String input,
    DocumentStream fallback = DocumentStream.inv,
  }) async {
    final specs = _parseInputs(input, fallback);
    if (specs.isEmpty) return const [];
    final repo = _repository ?? StagedDocumentRepository(await DatabaseService.database);
    return Future.wait([
      for (final spec in specs)
        spec.stream == null
            ? _resolveBare(
                entryId: entryId,
                digits: spec.documentNo,
                fallback: fallback,
                repo: repo,
              )
            : _resolveOne(
                entryId: entryId,
                stream: spec.stream!,
                documentNo: spec.documentNo,
                repo: repo,
              ),
    ]);
  }

  /// Comma/newline/space-separated tokens → specs. Prefix wins over the
  /// fallback chip; a BARE digits-only token probes all streams (the
  /// unique hit wins — no chip picking, no fat-finger prefix errors).
  /// Duplicates within one paste are silently collapsed.
  List<_Spec> _parseInputs(String input, DocumentStream fallback) {
    final specs = <_Spec>[];
    final seen = <String>{};
    for (final raw in input.split(RegExp(r'[,\n]+'))) {
      // Normalize: upper-case, no spaces/dashes ('dibt-0179154' →
      // 'DIBT0179154').
      final token =
          raw.trim().toUpperCase().replaceAll(RegExp(r'[\s-]+'), '');
      if (token.isEmpty) continue;
      if (token.startsWith('SCRAP')) {
        specs.add(_Spec(DocumentStream.rejects, 'SCRAPS'));
        continue;
      }
      // Bare digits-only token → probe all streams (stream = null).
      if (RegExp(r'^\d+$').hasMatch(token)) {
        if (seen.add('?:$token')) {
          specs.add(_Spec(null, token));
        }
        continue;
      }
      final parsed = DocumentNumberParser.parse(token, fallback);
      if (parsed == null) continue;
      final spec = _Spec(parsed.$1, parsed.$2);
      if (seen.add('${spec.stream?.name ?? '?'}:${spec.documentNo}')) {
        specs.add(spec);
      }
    }
    return specs;
  }

  /// A bare digits-only token — probe every stream in parallel and let
  /// the unique hit decide. Zero hits = not found; two+ = ask for the
  /// prefix (never guess).
  Future<DocumentResolveResult> _resolveBare({
    required String entryId,
    required String digits,
    required DocumentStream fallback,
    required StagedDocumentRepository repo,
  }) async {
    final streams = [
      fallback,
      ...DocumentStream.values.where(
        (s) => s != fallback && s != DocumentStream.rejects && s != DocumentStream.amsInv,
      ),
    ];
    final hits = <(DocumentStream, FetchedDocument)>[];
    Object? connectionError;
    await Future.wait([
      for (final s in streams)
        () async {
          try {
            final doc = await _fetcher(s, '${s.code}$digits');
            hits.add((s, doc));
          } on Exception catch (e) {
            if (!_isNotFound(e)) connectionError = e;
          }
        }(),
    ]);

    if (hits.isEmpty) {
      final status = connectionError != null
          ? DocumentResolveStatus.error
          : DocumentResolveStatus.notFound;
      return DocumentResolveResult._(
        input: digits,
        documentNo: digits,
        status: status,
        message: connectionError?.toString() ?? 'Document number not found',
      );
    }
    if (hits.length > 1) {
      final names = hits.map((h) => h.$1.code).join('/');
      return DocumentResolveResult._(
        input: digits,
        documentNo: digits,
        status: DocumentResolveStatus.error,
        message: 'Matches $names — add the prefix',
      );
    }
    final (stream, fetched) = hits.single;
    final documentNo = '${stream.code}$digits';
    final doc = StagedDocument(
      id: '$entryId:${stream.name}:$documentNo',
      entryId: entryId,
      stream: stream,
      documentNo: documentNo,
      customerName: fetched.customerName,
      customerCode: fetched.customerCode,
      total: fetched.total,
      slips: fetched.slips,
      lineItems: fetched.lineItems,
      cachedAt: DateTime.now().millisecondsSinceEpoch,
    );
    try {
      await repo.save(doc);
    } on DuplicateDocumentException catch (e) {
      return DocumentResolveResult._(
        input: digits,
        stream: stream,
        documentNo: documentNo,
        status: DocumentResolveStatus.duplicate,
        message: e.toString(),
      );
    }
    return DocumentResolveResult._(
      input: digits,
      stream: stream,
      documentNo: documentNo,
      status: DocumentResolveStatus.ok,
      document: doc,
    );
  }

  bool _isNotFound(Exception e) {
    final m = e.toString().toLowerCase();
    return m.contains('not found') ||
        m.contains('no document') ||
        m.contains('invalid document');
  }

  Future<DocumentResolveResult> _resolveOne({
    required String entryId,
    required DocumentStream stream,
    required String documentNo,
    required StagedDocumentRepository repo,
  }) async {
    if (stream == DocumentStream.rejects) {
      return DocumentResolveResult._(
        input: documentNo,
        stream: stream,
        documentNo: documentNo,
        status: DocumentResolveStatus.unsupported,
        message: 'SCRAPS is a mode, not a document',
      );
    }
    try {
      final fetched = await _fetcher(stream, documentNo);
      final doc = StagedDocument(
        id: '$entryId:${stream.name}:$documentNo',
        entryId: entryId,
        stream: stream,
        documentNo: documentNo,
        customerName: fetched.customerName,
        customerCode: fetched.customerCode,
        total: fetched.total,
        slips: fetched.slips,
        lineItems: fetched.lineItems,
        cachedAt: DateTime.now().millisecondsSinceEpoch,
      );
      try {
        await repo.save(doc);
      } on DuplicateDocumentException catch (e) {
        return DocumentResolveResult._(
          input: documentNo,
          stream: stream,
          documentNo: documentNo,
          status: DocumentResolveStatus.duplicate,
          message: e.toString(),
        );
      }
      return DocumentResolveResult._(
        input: documentNo,
        stream: stream,
        documentNo: documentNo,
        status: DocumentResolveStatus.ok,
        document: doc,
      );
    } on UnsupportedError catch (e) {
      return DocumentResolveResult._(
        input: documentNo,
        stream: stream,
        documentNo: documentNo,
        status: DocumentResolveStatus.unsupported,
        message: e.toString(),
      );
    } on Exception catch (e) {
      return DocumentResolveResult._(
        input: documentNo,
        stream: stream,
        documentNo: documentNo,
        status: _isNotFound(e)
            ? DocumentResolveStatus.notFound
            : DocumentResolveStatus.error,
        message: e.toString(),
      );
    }
  }
}
