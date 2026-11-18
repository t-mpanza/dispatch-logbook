import 'package:dispatch_diary/data/models/ibt_manifest.dart';
import 'package:dispatch_diary/data/models/staged_document.dart';
import 'package:dispatch_diary/dispatch/domain/document_number.dart';
import 'package:dispatch_diary/dispatch/domain/ibt_scan_engine.dart';
import 'package:dispatch_diary/dispatch/domain/multi_doc_scan_engine.dart';
import 'package:dispatch_diary/dispatch/models/slip_tyre.dart';
import 'package:flutter_test/flutter_test.dart';

/// The routing engine — TDD pins every locked decision:
/// D3 precedence (dump → collision → membership → IBT first-line-first →
/// cash armed-only → fail loud), D4 ambiguity, D5 offload window, D6 dump
/// in every mode, D7 cash untoggle prompt, D9 slip-number membership.
void main() {
  const reg = 'KH58XD';

  SlipTyre tyre({
    String? uid,
    int? slipNumber,
    String? job = 'Client Retread',
    int dump = 0,
    int? loaded,
    String? previousReg,
    int sizeId = 70,
    int rubberId = 36,
  }) =>
      SlipTyre(
        uid: uid,
        slipNumber: slipNumber,
        job: job,
        dump: dump,
        loaded: loaded,
        previousReg: previousReg,
        sizeId: sizeId,
        rubberId: rubberId,
        size: '315/80R22.5',
      );

  StagedDocument dibt({String no = 'DIBT0179154'}) => StagedDocument(
        id: 'e1:dibt:$no',
        entryId: 'e1',
        stream: DocumentStream.dibt,
        documentNo: no,
        customerName: 'EPS',
        total: 5,
        slips: [
          SlipTyre(uid: '1D0DF19A091080', slipNumber: 96962259, loaded: 0),
        ],
        cachedAt: 1,
      );

  StagedDocument inv() => StagedDocument(
        id: 'e1:inv:INV2392908',
        entryId: 'e1',
        stream: DocumentStream.inv,
        documentNo: 'INV2392908',
        customerName: 'EPS',
        total: 14,
        slips: [
          SlipTyre(uid: '1DCD7A9B091080', slipNumber: 96975621, loaded: 0),
        ],
        cachedAt: 1,
      );

  IbtLineItem line({
    required String id,
    required int target,
    int loaded = 0,
  }) =>
      IbtLineItem(
        id: id,
        description: '315/80R22.5 M90L STOCK RETREAD',
        sizeId: 70,
        rubberId: 36,
        targetTotal: target,
        loadedQuantity: loaded,
      );

  StagedDocument ibt({String no = 'IBT122773', List<IbtLineItem>? lines}) =>
      StagedDocument(
        id: 'e1:ibt:$no',
        entryId: 'e1',
        stream: DocumentStream.ibt,
        documentNo: no,
        total: 151,
        lineItems: lines ??
            [
              line(id: '${no}_line_0', target: 83),
              line(id: '${no}_line_1', target: 50, loaded: 50),
            ],
        cachedAt: 1,
      );

  MultiDocScanVerdict evaluate({
    List<StagedDocument> docs = const [],
    SlipTyre? scanned,
    Set<String> sessionUids = const {},
    bool cashArmed = false,
    int? operatorId = 816,
    String registration = reg,
    Set<String> externalLoadedUids = const {},
  }) =>
      MultiDocScanEngine.evaluate(
        stagedDocs: docs,
        tyre: scanned ?? tyre(uid: 'FFFFFFFFFFFFFF01'),
        sessionUids: sessionUids,
        cashArmed: cashArmed,
        operatorId: operatorId,
        registration: registration,
        externalLoadedUids: externalLoadedUids,
      );

  group('guards', () {
    test('missing operator rejects', () {
      final v = evaluate(operatorId: null);
      expect(v.message, contains('Operator'));
      expect(v.sound, ScanSound.error);
    });

    test('empty registration rejects', () {
      final v = evaluate(registration: '');
      expect(v.message, contains('REG'));
    });
  });

  group('D6 — dump blocks in every mode', () {
    test('normal mode', () {
      final v = evaluate(scanned: tyre(dump: 1));
      expect(v, isA<DumpedTyre>());
    });

    test('cash armed too', () {
      final v = evaluate(cashArmed: true, scanned: tyre(dump: 1));
      expect(v, isA<DumpedTyre>());
    });

    test('even when the tyre is on a document', () {
      final v = evaluate(
        docs: [dibt()],
        scanned: tyre(uid: '1D0DF19A091080', dump: 1),
      );
      expect(v, isA<DumpedTyre>());
    });
  });

  group('D5 — offload window', () {
    test('session duplicate (double-scan) prompts offload', () {
      final v = evaluate(sessionUids: {'FFFFFFFFFFFFFF01'});
      expect(v, isA<OffloadPrompt>());
      expect(v.sound, ScanSound.error);
    });

    test('tyre already loaded on OUR truck prompts offload', () {
      final d = dibt();
      final v = evaluate(
        docs: [
          StagedDocument(
            id: d.id,
            entryId: d.entryId,
            stream: d.stream,
            documentNo: d.documentNo,
            slips: [
              SlipTyre(
                uid: '1D0DF19A091080',
                slipNumber: 96962259,
                loaded: 1,
                previousReg: reg,
              ),
            ],
            cachedAt: 1,
          ),
        ],
        scanned: tyre(uid: '1D0DF19A091080'),
      );
      expect(v, isA<OffloadPrompt>());
    });

    test(
        'external loaded uids (persisted cash scans) prompt offload '
        'across sessions — audit #3', () {
      // No session state, no manifest entry — but the tyre was committed
      // as cash in a PREVIOUS session and is persisted.
      final v = evaluate(
        externalLoadedUids: const {'FFFFFFFFFFFFFF01'},
        scanned: tyre(uid: 'FFFFFFFFFFFFFF01'),
      );
      expect(v, isA<OffloadPrompt>());
      expect(v.sound, ScanSound.error);
    });
  });

  group('offload — reg is never a blocker (field rule 2026-11-18)', () {
    test('loaded with a different previous_reg still offers the offload', () {
      final d = dibt();
      final v = evaluate(
        docs: [
          StagedDocument(
            id: d.id,
            entryId: d.entryId,
            stream: d.stream,
            documentNo: d.documentNo,
            slips: [
              SlipTyre(
                uid: '1D0DF19A091080',
                slipNumber: 96962259,
                loaded: 1,
                previousReg: 'MB75JMGP',
              ),
            ],
            cachedAt: 1,
          ),
        ],
        scanned: tyre(uid: '1D0DF19A091080'),
      );
      expect(v, isA<OffloadPrompt>());
      final offload = v as OffloadPrompt;
      expect(offload.previousReg, 'MB75JMGP');
      expect(v.message, contains('MB75JMGP'));
    });

    test('offers offload in cash mode too (left-behind tyre)', () {
      final d = dibt();
      final v = evaluate(
        cashArmed: true,
        docs: [
          StagedDocument(
            id: d.id,
            entryId: d.entryId,
            stream: d.stream,
            documentNo: d.documentNo,
            slips: [
              SlipTyre(
                uid: '1D0DF19A091080',
                slipNumber: 96962259,
                loaded: 1,
                previousReg: 'MB75JMGP',
              ),
            ],
            cachedAt: 1,
          ),
        ],
        scanned: tyre(uid: '1D0DF19A091080'),
      );
      expect(v, isA<OffloadPrompt>());
    });
  });

  group('membership routing', () {
    test('single matching doc accepts into it', () {
      final v = evaluate(
        docs: [dibt(), inv()],
        scanned: tyre(uid: '1DCD7A9B091080'),
      );
      expect(v, isA<AcceptedIntoDocument>());
      final a = v as AcceptedIntoDocument;
      expect(a.documentNo, 'INV2392908');
      expect(v.isSuccess, isTrue);
      expect(v.sound, ScanSound.success);
    });

    test('D9 — slip-number membership when the uid is unknown', () {
      final v = evaluate(
        docs: [dibt()],
        scanned: tyre(uid: null, slipNumber: 96962259),
      );
      expect(v, isA<AcceptedIntoDocument>());
      expect((v as AcceptedIntoDocument).documentNo, 'DIBT0179154');
    });

    test('D4 — two documents containing the tyre = ambiguous', () {
      final both = dibt();
      final v = evaluate(
        docs: [
          StagedDocument(
            id: both.id,
            entryId: both.entryId,
            stream: both.stream,
            documentNo: both.documentNo,
            slips: [
              SlipTyre(uid: '1DCD7A9B091080', slipNumber: 96962259, loaded: 0),
            ],
            cachedAt: 1,
          ),
          inv(),
        ],
        scanned: tyre(uid: '1DCD7A9B091080'),
      );
      expect(v, isA<AmbiguousDocument>());
      final a = v as AmbiguousDocument;
      expect(a.documentNos, containsAll(['DIBT0179154', 'INV2392908']));
      expect(v.sound, ScanSound.error);
    });
  });

  group('IBT routing — first line first (D3)', () {
    test('two matching lines with capacity → FIRST in manifest order', () {
      final v = evaluate(
        docs: [
          ibt(lines: [
            line(id: 'IBT122773_line_0', target: 83),
            line(id: 'IBT122773_line_1', target: 83),
          ]),
        ],
        scanned: tyre(uid: 'FFFFFFFFFFFFFF01'),
      );
      expect(v, isA<AcceptedIntoDocument>());
      final a = v as AcceptedIntoDocument;
      expect(a.documentNo, 'IBT122773');
      expect(a.lineId, 'IBT122773_line_0');
    });

    test('first line full → spills to the next', () {
      final v = evaluate(
        docs: [
          ibt(lines: [
            line(id: 'IBT122773_line_0', target: 83, loaded: 83),
            line(id: 'IBT122773_line_1', target: 50),
          ]),
        ],
        scanned: tyre(uid: 'FFFFFFFFFFFFFF01'),
      );
      final a = v as AcceptedIntoDocument;
      expect(a.lineId, 'IBT122773_line_1');
    });

    test('wrong job never matches an IBT', () {
      final v = evaluate(
        docs: [ibt()],
        scanned: tyre(uid: 'FFFFFFFFFFFFFF01', job: 'Retread & Repair'),
      );
      expect(v, isA<Rejected>());
      expect(v.message, contains('Not on this truck'));
    });

    test('all matching lines full → loud reject', () {
      final v = evaluate(
        docs: [
          ibt(lines: [
            line(id: 'IBT122773_line_0', target: 83, loaded: 83),
            line(id: 'IBT122773_line_1', target: 50, loaded: 50),
          ]),
        ],
        scanned: tyre(uid: 'FFFFFFFFFFFFFF01'),
      );
      expect(v, isA<Rejected>());
      expect(v.message, contains('full'));
      expect(v.sound, ScanSound.error);
    });
  });

  group('D7 — cash armed mode', () {
    test('unmatched tyre is accepted as cash', () {
      final v = evaluate(
        cashArmed: true,
        docs: [dibt(), inv()],
        scanned: tyre(uid: 'FFFFFFFFFFFFFF02'),
      );
      expect(v, isA<AcceptedAsCash>());
      expect(v.isSuccess, isTrue);
    });

    test('tyre on a document → fail loud + untoggle prompt', () {
      final v = evaluate(
        cashArmed: true,
        docs: [dibt(), inv()],
        scanned: tyre(uid: '1DCD7A9B091080'),
      );
      expect(v, isA<UntoggleCashPrompt>());
      expect((v as UntoggleCashPrompt).documentNo, 'INV2392908');
      expect(v.sound, ScanSound.error);
    });

    test('tyre fitting an IBT line → fail loud + untoggle prompt', () {
      final v = evaluate(
        cashArmed: true,
        docs: [ibt()],
        scanned: tyre(uid: 'FFFFFFFFFFFFFF03'),
      );
      expect(v, isA<UntoggleCashPrompt>());
      expect((v as UntoggleCashPrompt).documentNo, 'IBT122773');
    });
  });

  group('nothing matches', () {
    test('no doc, no IBT fit, not armed → loud reject', () {
      final v = evaluate(
        docs: [dibt(), ibt()],
        scanned: tyre(uid: 'FFFFFFFFFFFFFF09', job: 'Retread & Repair', sizeId: 99),
      );
      expect(v, isA<Rejected>());
      expect(v.message, contains('Not on this truck'));
      expect(v.sound, ScanSound.error);
    });
  });
}
