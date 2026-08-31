// ignore_for_file: constant_identifier_names
enum PresetKey {
  DBN,
  NLS,
  BLOEM,
  PLK,
  STOCKS,
  NLH,
  TIREPOINT,
  CUSTOM,
}

class PresetConfig {
  final PresetKey key;
  final String label;
  final String? defaultDriver;
  final String? defaultReg;
  final bool isDynamic;

  const PresetConfig({
    required this.key,
    required this.label,
    this.defaultDriver,
    this.defaultReg,
    this.isDynamic = false,
  });
}

class PresetEngine {
  static const List<PresetConfig> loadingPresets = [
    PresetConfig(key: PresetKey.DBN, label: "DBN"),
    PresetConfig(key: PresetKey.NLS, label: "NLS"),
    PresetConfig(key: PresetKey.BLOEM, label: "BLOEM"),
    PresetConfig(key: PresetKey.PLK, label: "PLK"),
    PresetConfig(key: PresetKey.STOCKS, label: "STOCKS [i]", isDynamic: true),
    PresetConfig(
      key: PresetKey.NLH,
      label: "NLH",
      defaultDriver: "Neil",
      defaultReg: "MN05XNGP",
    ),
    PresetConfig(key: PresetKey.TIREPOINT, label: "TIREPOINT"),
    PresetConfig(key: PresetKey.CUSTOM, label: "Custom"),
  ];

  static String getNextStocksTripId(List<String> existingTripIds) {
    int maxExisting = 0;
    final stocksRegex = RegExp(r'^STOCKS\s+(\d+)$', caseSensitive: false);

    for (final tripId in existingTripIds) {
      final match = stocksRegex.firstMatch(tripId.trim());
      if (match != null) {
        final numVal = int.tryParse(match.group(1)!);
        if (numVal != null && numVal > maxExisting) {
          maxExisting = numVal;
        }
      }
    }

    final nextIndex = maxExisting + 1;
    return 'STOCKS $nextIndex';
  }

  static PresetFillResult getPresetFill(
    PresetKey key, {
    List<String> existingTripIds = const [],
  }) {
    switch (key) {
      case PresetKey.NLH:
        return const PresetFillResult(
          presetKey: PresetKey.NLH,
          tripId: 'NLH',
          driverName: 'Neil',
          reg: 'MN05XNGP',
        );
      case PresetKey.STOCKS:
        return PresetFillResult(
          presetKey: PresetKey.STOCKS,
          tripId: getNextStocksTripId(existingTripIds),
        );
      case PresetKey.CUSTOM:
        return const PresetFillResult(
          presetKey: PresetKey.CUSTOM,
          tripId: '',
        );
      default:
        return PresetFillResult(
          presetKey: key,
          tripId: key.name,
        );
    }
  }
}

class PresetFillResult {
  final PresetKey presetKey;
  final String tripId;
  final String? driverName;
  final String? reg;

  const PresetFillResult({
    required this.presetKey,
    required this.tripId,
    this.driverName,
    this.reg,
  });
}
