import 'json_helpers.dart';

/// One scan-history row of a tyre (`getTyreHistory`).
class TyreHistoryEntry {
  const TyreHistoryEntry({
    this.firstName,
    this.lastName,
    this.workCellName,
    this.scanInTime,
    this.scanOutTime,
    this.scanOut,
  });

  final String? firstName;
  final String? lastName;
  final String? workCellName;
  final String? scanInTime;
  final String? scanOutTime;
  final int? scanOut;

  String get operatorName {
    final name = [firstName, lastName].whereType<String>().join(' ').trim();
    return name.isEmpty ? '—' : name;
  }

  String? get newestTimestamp => scanInTime ?? scanOutTime;

  factory TyreHistoryEntry.fromJson(Map<String, dynamic> json) =>
      TyreHistoryEntry(
        firstName: jsonString(json['first_name']),
        lastName: jsonString(json['last_name']),
        workCellName: jsonString(json['work_cell_name']),
        scanInTime: jsonString(json['scan_in_time']),
        scanOutTime: jsonString(json['scan_out_time']),
        scanOut: jsonInt(json['scan_out']),
      );
}

/// One row of `listTyresAtDispatchFull`.
class DispatchTyre {
  const DispatchTyre({
    this.idSlip,
    this.slipNumber,
    this.csNumber,
    this.customerName,
    this.size,
    this.make,
    this.serial,
    this.pattern,
    this.atDispatch,
    this.invoiced,
    this.throughDispatchInspection,
    this.firstInTime,
    this.evoStatus,
    this.idConfirmationSheet,
  });

  final int? idSlip;
  final int? slipNumber;
  final String? csNumber;
  final String? customerName;
  final String? size;
  final String? make;
  final String? serial;
  final String? pattern;
  final int? atDispatch;
  final int? invoiced;
  final int? throughDispatchInspection;
  final String? firstInTime;
  final String? evoStatus;
  final int? idConfirmationSheet;

  String get displayLabel {
    final parts = [
      if (size != null && size!.isNotEmpty) size!,
      if (make != null && make!.isNotEmpty) make!,
      if (pattern != null && pattern!.isNotEmpty) pattern!,
    ];
    return parts.isEmpty ? '${serial ?? slipNumber ?? 'Tyre'}' : parts.join(' · ');
  }

  factory DispatchTyre.fromJson(Map<String, dynamic> json) => DispatchTyre(
    idSlip: jsonInt(json['idSlip']),
    slipNumber: jsonInt(json['slip_number']),
    csNumber: jsonString(json['cs_number']),
    customerName: jsonString(json['CustomerName']),
    size: jsonString(json['size']),
    make: jsonString(json['make']),
    serial: jsonString(json['serial']),
    pattern: jsonString(json['pattern']),
    atDispatch: jsonInt(json['at_dispatch']),
    invoiced: jsonInt(json['invoiced']),
    throughDispatchInspection: jsonInt(json['through_dispatch_inspection']),
    firstInTime: jsonString(json['first_in_time']),
    evoStatus: jsonString(json['EVO_status']),
    idConfirmationSheet: jsonInt(json['idConfirmation_Sheet']),
  );
}

/// One row of `listOutstandingBatches`.
class OutstandingBatch {
  const OutstandingBatch({
    this.slips,
    this.customerName,
    this.createdAt,
    this.csNumber,
    this.atDispatch,
    this.firstInTime,
    this.idConfirmationSheet,
    this.firstOutTime,
    this.lastOutTime,
  });

  final int? slips;
  final String? customerName;
  final String? createdAt;
  final String? csNumber;
  final int? atDispatch;
  final String? firstInTime;
  final int? idConfirmationSheet;
  final String? firstOutTime;
  final String? lastOutTime;

  factory OutstandingBatch.fromJson(Map<String, dynamic> json) =>
      OutstandingBatch(
        slips: jsonInt(json['slips']),
        customerName: jsonString(json['CustomerName']),
        createdAt: jsonString(json['created_at']),
        csNumber: jsonString(json['cs_number']),
        atDispatch: jsonInt(json['at_dispatch']),
        firstInTime: jsonString(json['first_in_time']),
        idConfirmationSheet: jsonInt(json['idConfirmation_Sheet']),
        firstOutTime: jsonString(json['first_out_time']),
        lastOutTime: jsonString(json['last_out_time']),
      );
}

/// One row of `getLateBatchQuery`.
class LateBatchTyre {
  const LateBatchTyre({
    this.idConfirmationSheet,
    this.firstOutTime,
    this.csNumber,
    this.reference,
    this.customerName,
    this.idSlip,
    this.slipNumber,
    this.make,
    this.size,
    this.serial,
    this.job,
    this.pattern,
    this.positionInBatch,
  });

  final int? idConfirmationSheet;
  final String? firstOutTime;
  final String? csNumber;
  final String? reference;
  final String? customerName;
  final int? idSlip;
  final int? slipNumber;
  final String? make;
  final String? size;
  final String? serial;
  final String? job;
  final String? pattern;
  final int? positionInBatch;

  factory LateBatchTyre.fromJson(Map<String, dynamic> json) => LateBatchTyre(
    idConfirmationSheet: jsonInt(json['idConfirmation_Sheet']),
    firstOutTime: jsonString(json['first_out_time']),
    csNumber: jsonString(json['cs_number']),
    reference: jsonString(json['reference']),
    customerName: jsonString(json['CustomerName']),
    idSlip: jsonInt(json['idSlip']),
    slipNumber: jsonInt(json['slip_number']),
    make: jsonString(json['make']),
    size: jsonString(json['size']),
    serial: jsonString(json['serial']),
    job: jsonString(json['job']),
    pattern: jsonString(json['pattern']),
    positionInBatch: jsonInt(json['position_in_batch']),
  );
}

/// One row of `getShiftTotal`.
class ShiftTotal {
  const ShiftTotal({this.workCellName, this.numberOfTyres, this.workCellId, this.cellQuota});

  final String? workCellName;
  final int? numberOfTyres;
  final int? workCellId;
  final int? cellQuota;

  factory ShiftTotal.fromJson(Map<String, dynamic> json) => ShiftTotal(
    workCellName: jsonString(json['work_cell_name']),
    numberOfTyres: jsonInt(json['number_of_tyres']),
    workCellId: jsonInt(json['work_cell_id']),
    cellQuota: jsonInt(json['cell_quota']),
  );
}

/// One row of `getActiveDispatchSession`.
class ActiveDispatchSession {
  const ActiveDispatchSession({
    this.idDispatchSession,
    this.iLocationId,
    this.cLocation,
    this.iPersonnelId,
    this.cName,
    this.bPrep,
    this.cComment,
    this.dStartTime,
  });

  final int? idDispatchSession;
  final int? iLocationId;
  final String? cLocation;
  final int? iPersonnelId;
  final String? cName;
  final int? bPrep;
  final String? cComment;
  final String? dStartTime;

  factory ActiveDispatchSession.fromJson(Map<String, dynamic> json) =>
      ActiveDispatchSession(
        idDispatchSession: jsonInt(json['idDispatch_Session']),
        iLocationId: jsonInt(json['iLocation_ID']),
        cLocation: jsonString(json['cLocation']),
        iPersonnelId: jsonInt(json['iPersonnel_ID']),
        cName: jsonString(json['cName']),
        bPrep: jsonInt(json['bPrep']),
        cComment: jsonString(json['cComment']),
        dStartTime: jsonString(json['dStart_Time']),
      );
}

/// One row of `getDispatchSession` (tyres of a dispatched session).
class DispatchSessionTyre {
  const DispatchSessionTyre({
    this.idSlip,
    this.slipNumber,
    this.make,
    this.size,
    this.serial,
    this.jobType,
    this.pattern,
    this.customerName,
    this.customerCode,
  });

  final int? idSlip;
  final String? slipNumber;
  final String? make;
  final String? size;
  final String? serial;
  final String? jobType;
  final String? pattern;
  final String? customerName;
  final String? customerCode;

  factory DispatchSessionTyre.fromJson(Map<String, dynamic> json) =>
      DispatchSessionTyre(
        idSlip: jsonInt(json['idSlip']),
        slipNumber: jsonString(json['cSlip_Number']),
        make: jsonString(json['cMake']),
        size: jsonString(json['cSize']),
        serial: jsonString(json['cSerial']),
        jobType: jsonString(json['cJob_Type']),
        pattern: jsonString(json['cPattern']),
        customerName: jsonString(json['cCustomer_Name']),
        customerCode: jsonString(json['cCustomer_Code']),
      );
}

/// One row of `getSlipWithNumber`.
class SlipDetail {
  const SlipDetail({
    this.idSlip,
    this.slipNumber,
    this.tyreId,
    this.jobId,
    this.csId,
    this.onRim,
    this.rubberId,
    this.positionInBatch,
    this.jobStaged,
    this.throughInitialInspection,
    this.readyToCut,
    this.missing,
    this.noGuarantee,
    this.casingGrade,
    this.casingAdded,
    this.invoiced,
    this.casingCode,
    this.rejectAccepted,
    this.greenBlock,
    this.invoiceNumber,
    this.previousSlipId,
    this.repeatUid,
    this.throughFinalInspection,
    this.throughDispatchInspection,
    this.createdAt,
    this.late,
    this.circumference,
    this.width,
  });

  final int? idSlip;
  final int? slipNumber;
  final int? tyreId;
  final int? jobId;
  final int? csId;
  final int? onRim;
  final int? rubberId;
  final int? positionInBatch;
  final int? jobStaged;
  final int? throughInitialInspection;
  final int? readyToCut;
  final int? missing;
  final int? noGuarantee;
  final String? casingGrade;
  final int? casingAdded;
  final int? invoiced;
  final String? casingCode;
  final int? rejectAccepted;
  final int? greenBlock;
  final String? invoiceNumber;
  final int? previousSlipId;
  final String? repeatUid;
  final int? throughFinalInspection;
  final int? throughDispatchInspection;
  final String? createdAt;
  final int? late;
  final String? circumference;
  final String? width;

  factory SlipDetail.fromJson(Map<String, dynamic> json) => SlipDetail(
    idSlip: jsonInt(json['idSlip']),
    slipNumber: jsonInt(json['slip_number']),
    tyreId: jsonInt(json['tyre_id']),
    jobId: jsonInt(json['job_id']),
    csId: jsonInt(json['cs_id']),
    onRim: jsonInt(json['on_rim']),
    rubberId: jsonInt(json['rubber_id']),
    positionInBatch: jsonInt(json['position_in_batch']),
    jobStaged: jsonInt(json['job_staged']),
    throughInitialInspection: jsonInt(json['through_initial_inspection']),
    readyToCut: jsonInt(json['ready_to_cut']),
    missing: jsonInt(json['missing']),
    noGuarantee: jsonInt(json['no_guarantee']),
    casingGrade: jsonString(json['casing_grade']),
    casingAdded: jsonInt(json['casing_added']),
    invoiced: jsonInt(json['invoiced']),
    casingCode: jsonString(json['casing_code']),
    rejectAccepted: jsonInt(json['reject_accepted']),
    greenBlock: jsonInt(json['green_block']),
    invoiceNumber: jsonString(json['invoice_number']),
    previousSlipId: jsonInt(json['previous_slip_id']),
    repeatUid: jsonString(json['repeat_uid']),
    throughFinalInspection: jsonInt(json['through_final_inspection']),
    throughDispatchInspection: jsonInt(json['through_dispatch_inspection']),
    createdAt: jsonString(json['created_at']),
    late: jsonInt(json['late']),
    circumference: jsonString(json['circumference']),
    width: jsonString(json['width']),
  );
}
