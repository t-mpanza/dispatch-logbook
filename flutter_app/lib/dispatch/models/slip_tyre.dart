import 'json_helpers.dart';
import '../domain/scrap_marker.dart';

/// A single tyre slip as returned live by `getSlipTyreWithUID` /
/// `getSlipTyreWithCSID` (`Slip_Tyre_Info`) and `getDeliveryInfo`
/// (`DispatchDeliverySlipInfo`). Field names mirror the live SDL exactly,
/// including the mixed casing.
class SlipTyre {
  const SlipTyre({
    this.uid,
    this.idSlip,
    this.idTyre,
    this.slipNumber,
    this.pattern,
    this.idConfirmationSheet,
    this.customerName,
    this.csNumber,
    this.make,
    this.size,
    this.serial,
    this.dot,
    this.driver,
    this.reference,
    this.registration,
    this.locationId,
    this.rejectAccepted,
    this.invoiced,
    this.invoiceNumber,
    this.orderNumber,
    this.dump,
    this.tagged,
    this.job,
    this.onRim,
    this.loaded,
    this.previousReg,
    this.scanTime,
    this.name,
    this.locationCode,
  });

  final String? uid;
  final int? idSlip;
  final int? idTyre;
  final int? slipNumber;
  final String? pattern;
  final int? idConfirmationSheet;
  final String? customerName;
  final String? csNumber;
  final String? make;
  final String? size;
  final String? serial;
  final String? dot;
  final String? driver;
  final String? reference;
  final String? registration;
  final int? locationId;
  final int? rejectAccepted;
  final int? invoiced;
  final String? invoiceNumber;
  final String? orderNumber;
  final int? dump;
  final int? tagged;
  final String? job;
  final int? onRim;
  final int? loaded;
  final String? previousReg;
  final String? scanTime;
  final String? name;
  final String? locationCode;

  bool get isLoaded => (loaded ?? 0) == 1;
  bool get isRejectAccepted => (rejectAccepted ?? 0) == 1;
  bool get isDump => (dump ?? 0) == 1;
  bool get isOnRim => (onRim ?? 0) == 1;
  bool get isClaim => job != null && job!.trim().toUpperCase() == 'CLAIM';

  /// Failed tyre (scrap): `reject_accepted = 2`, a `DUD` code in the
  /// visible fields or the backend dump flag.
  bool get isScrap => ScrapMarker.isScrap(
    serial: serial,
    pattern: pattern,
    size: size,
    dump: dump,
    rejectAccepted: rejectAccepted,
  );

  String get displayLabel {
    final parts = [
      if (size != null && size!.isNotEmpty) size!,
      if (make != null && make!.isNotEmpty) make!,
      if (pattern != null && pattern!.isNotEmpty) pattern!,
    ];
    return parts.isEmpty ? (serial ?? uid ?? 'Tyre') : parts.join(' · ');
  }

  factory SlipTyre.fromJson(Map<String, dynamic> json) => SlipTyre(
    uid: jsonString(json['uid']),
    idSlip: jsonInt(json['idSlip']),
    idTyre: jsonInt(json['idTyre']),
    slipNumber: jsonInt(json['slip_number']),
    pattern: jsonString(json['pattern']),
    idConfirmationSheet: jsonInt(json['idConfirmation_Sheet']),
    customerName: jsonString(json['CustomerName']),
    csNumber: jsonString(json['cs_number']),
    make: jsonString(json['make']),
    size: jsonString(json['size']),
    serial: jsonString(json['serial']),
    dot: jsonString(json['dot']),
    driver: jsonString(json['driver']),
    reference: jsonString(json['reference']),
    registration: jsonString(json['registration']),
    locationId: jsonInt(json['location_id']),
    rejectAccepted: jsonInt(json['reject_accepted']),
    invoiced: jsonInt(json['invoiced']),
    invoiceNumber: jsonString(json['invoice_number']),
    orderNumber: jsonString(json['order_number']),
    dump: jsonInt(json['dump']),
    tagged: jsonInt(json['tagged']),
    job: jsonString(json['job']),
    onRim: jsonInt(json['on_rim']),
    loaded: jsonInt(json['loaded']),
    previousReg: jsonString(json['previous_reg']),
    scanTime: jsonString(json['scan_time']),
    name: jsonString(json['name']),
    locationCode: jsonString(json['location_code']),
  );
}
