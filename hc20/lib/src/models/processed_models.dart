class Hc20Device {
  final String id;
  final String name;
  Hc20Device(this.id, this.name);
}

class Hc20DeviceInfo {
  final String name;
  final String mac;
  final String version;
  final String? versionTag;
  final String? buildTime;
  Hc20DeviceInfo(
      {required this.name,
      required this.mac,
      required this.version,
      this.versionTag,
      this.buildTime});

  factory Hc20DeviceInfo.fromJson(Map<String, dynamic> j) => Hc20DeviceInfo(
        name: j['name'] ?? '',
        mac: j['mac'] ?? '',
        version: j['version'] ?? '',
        versionTag: j['version_tag'],
        buildTime: j['build_time'],
      );
}

class Hc20Time {
  final int timestamp;
  final int timezone;
  Hc20Time(this.timestamp, this.timezone);
}

class Hc20BatteryInfo {
  final int percent;
  final int charge; // 0,1,2
  Hc20BatteryInfo(this.percent, this.charge);
}

// (V1 removed)

class Hc20HrvMetrics {
  final int sdnn, tp, lf, hf, vlf;
  Hc20HrvMetrics(this.sdnn, this.tp, this.lf, this.hf, this.vlf);
}

class Hc20Hrv2Metrics {
  final int mentStress, fatigueLevel, stressResistance, regulationAbility;
  Hc20Hrv2Metrics(this.mentStress, this.fatigueLevel, this.stressResistance,
      this.regulationAbility);
}

class Hc20RealtimeV2 {
  final Hc20BatteryInfo? battery;
  final List<int>? basicData; // steps, calories, distance
  final int? heart, rri, spo2;
  final List<int>? bp; // sys,dia
  final List<int>? temperature; // hand,env,body (x100)
  final int? baro, wear;
  final List<int>? sleep; // status,deep,light,rem,sober
  final List<num>? gnss; // onoff,sigqual,timestamp,lat,lon,alt
  final List<int>? hrv; // SDNN,TP,LF,HF,VLF (x1000)
  final List<int>? hrv2; // ment_stress,fatigue,stress_res,reg_ablty
  final Hc20HrvMetrics? hrvMetrics;
  final Hc20Hrv2Metrics? hrv2Metrics;

  Hc20RealtimeV2(
      {this.battery,
      this.basicData,
      this.heart,
      this.rri,
      this.spo2,
      this.bp,
      this.temperature,
      this.baro,
      this.wear,
      this.sleep,
      this.gnss,
      this.hrv,
      this.hrv2,
      this.hrvMetrics,
      this.hrv2Metrics});

  factory Hc20RealtimeV2.fromMap(Map<String, dynamic> m) {
    Hc20BatteryInfo? batt;
    if (m['battery'] is String) {
      final parts = (m['battery'] as String)
          .split(',')
          .map((e) => int.tryParse(e.trim()) ?? 0)
          .toList();
      batt = Hc20BatteryInfo(
          parts.isNotEmpty ? parts[0] : 0, parts.length > 1 ? parts[1] : 0);
    }
    List<int>? _ints(String k) => m[k] is String
        ? (m[k] as String)
            .split(',')
            .map((e) => int.tryParse(e.trim()) ?? 0)
            .toList()
        : null;
    List<num>? _nums(String k) => m[k] is String
        ? (m[k] as String)
            .split(',')
            .map((e) => num.tryParse(e.trim()) ?? 0)
            .toList()
        : null;

    Hc20HrvMetrics? hrvM;
    final hrvList = _ints('hrv');
    if (hrvList != null && hrvList.length >= 5) {
      hrvM = Hc20HrvMetrics(
          hrvList[0], hrvList[1], hrvList[2], hrvList[3], hrvList[4]);
    }

    Hc20Hrv2Metrics? hrv2M;
    final hrv2List = _ints('hrv2');
    if (hrv2List != null && hrv2List.length >= 4) {
      hrv2M =
          Hc20Hrv2Metrics(hrv2List[0], hrv2List[1], hrv2List[2], hrv2List[3]);
    }

    return Hc20RealtimeV2(
      battery: batt,
      basicData: _ints('basic_data'),
      heart: m['heart'],
      rri: m['rri'],
      spo2: m['spo2'],
      bp: _ints('bp'),
      temperature: _ints('temperature'),
      baro: m['baro'],
      wear: m['wear'],
      sleep: _ints('sleep'),
      gnss: _nums('gnss'),
      hrv: hrvList,
      hrv2: hrv2List,
      hrvMetrics: hrvM,
      hrv2Metrics: hrv2M,
    );
  }
}

enum Hc20HistoryType {
  allDaySummary,
  heart5s,
  steps5m,
  spo25m,
  rri5s,
  temperature1m,
  baro1m,
  bp5m,
  hrv5m,
  gnss1m,
  sleep,
  calories5m,
  hrv2_5m,
  packetStatus,
  storageInfo
}

class Hc20AllDayRow {
  final String dateTime;
  final Map<String, dynamic> values;
  final bool valid;

  const Hc20AllDayRow(
      {required this.dateTime, required this.values, required this.valid});

  Map<String, dynamic> toJson() => {
        'dateTime': dateTime,
        'values': values,
        'valid': valid,
      };
}

extension Hc20HistoryTypeCodec on Hc20HistoryType {
  int get typeId {
    switch (this) {
      case Hc20HistoryType.allDaySummary:
        return 0x00;
      case Hc20HistoryType.heart5s:
        return 0x01;
      case Hc20HistoryType.steps5m:
        return 0x02;
      case Hc20HistoryType.spo25m:
        return 0x03;
      case Hc20HistoryType.rri5s:
        return 0x04;
      case Hc20HistoryType.temperature1m:
        return 0x05;
      case Hc20HistoryType.baro1m:
        return 0x06;
      case Hc20HistoryType.bp5m:
        return 0x07;
      case Hc20HistoryType.hrv5m:
        return 0x08;
      case Hc20HistoryType.gnss1m:
        return 0x09;
      case Hc20HistoryType.sleep:
        return 0x0A;
      case Hc20HistoryType.calories5m:
        return 0x0B;
      case Hc20HistoryType.hrv2_5m:
        return 0x0C;
      case Hc20HistoryType.packetStatus:
        return 0xFD;
      case Hc20HistoryType.storageInfo:
        return 0xFE;
    }
  }

  bool get isAllDayMetric {
    switch (this) {
      case Hc20HistoryType.allDaySummary:
      case Hc20HistoryType.heart5s:
      case Hc20HistoryType.steps5m:
      case Hc20HistoryType.spo25m:
      case Hc20HistoryType.rri5s:
      case Hc20HistoryType.temperature1m:
      case Hc20HistoryType.baro1m:
      case Hc20HistoryType.bp5m:
      case Hc20HistoryType.hrv5m:
      case Hc20HistoryType.gnss1m:
      case Hc20HistoryType.sleep:
      case Hc20HistoryType.calories5m:
      case Hc20HistoryType.hrv2_5m:
        return true;
      case Hc20HistoryType.packetStatus:
      case Hc20HistoryType.storageInfo:
        return false;
    }
  }
}

class Hc20AllDaySummary {
  final int steps,
      calories,
      distance,
      activeTime,
      silentTime,
      activeCalories,
      silentCalories;
  Hc20AllDaySummary(
      {required this.steps,
      required this.calories,
      required this.distance,
      required this.activeTime,
      required this.silentTime,
      required this.activeCalories,
      required this.silentCalories});
  factory Hc20AllDaySummary.fromJson(Map<String, dynamic> j) =>
      Hc20AllDaySummary(
        steps: j['steps'] ?? 0,
        calories: j['calories'] ?? 0,
        distance: j['distance'] ?? 0,
        activeTime: j['active_time'] ?? 0,
        silentTime: j['silent_time'] ?? 0,
        activeCalories: j['active_calories'] ?? 0,
        silentCalories: j['silent_calories'] ?? 0,
      );
}

class Hc20SleepSummary {
  final int sober, light, deep, rem, nap;
  Hc20SleepSummary(this.sober, this.light, this.deep, this.rem, this.nap);
}

class Hc20SleepDetailTimestamp {
  final int y; // date index (0-31) per spec field semantics
  final int h;
  final int m;
  Hc20SleepDetailTimestamp(this.y, this.h, this.m);
}

class Hc20SleepDetail {
  final int state;
  final Hc20SleepDetailTimestamp timestamp;
  Hc20SleepDetail(this.state, this.timestamp);
}

// Enhanced data models with timing and validity information
class Hc20DataPoint {
  final int slot; // 0..N within this packet
  final int minuteOfDay; // minutes since 00:00 for that slot
  final String timeHHMM; // human-readable clock time (local day)
  final bool valid; // whether data is real (not invalid marker)

  Hc20DataPoint(this.slot, this.minuteOfDay, this.timeHHMM, this.valid);
}

class Hc20Heart5sPoint extends Hc20DataPoint {
  final int? bpm; // heart rate in bpm, or null if invalid
  Hc20Heart5sPoint(
      super.slot, super.minuteOfDay, super.timeHHMM, super.valid, this.bpm);
}

class Hc20Steps5mPoint extends Hc20DataPoint {
  final int? steps; // steps in that 5-min block, or null if invalid
  Hc20Steps5mPoint(
      super.slot, super.minuteOfDay, super.timeHHMM, super.valid, this.steps);
}

class Hc20Spo25mPoint extends Hc20DataPoint {
  final int? spo2; // SpO2 percentage, or null if invalid
  Hc20Spo25mPoint(
      super.slot, super.minuteOfDay, super.timeHHMM, super.valid, this.spo2);
}

class Hc20Rri5sPoint extends Hc20DataPoint {
  final int? rriMs; // RRI in milliseconds, or null if invalid
  Hc20Rri5sPoint(
      super.slot, super.minuteOfDay, super.timeHHMM, super.valid, this.rriMs);
}

class Hc20Temp1mPoint extends Hc20DataPoint {
  final double? surfaceC; // surface temperature in °C, or null if invalid
  final double? ambientC; // ambient temperature in °C, or null if invalid
  Hc20Temp1mPoint(super.slot, super.minuteOfDay, super.timeHHMM, super.valid,
      this.surfaceC, this.ambientC);
}

class Hc20Baro1mPoint extends Hc20DataPoint {
  final int? pascals; // barometric pressure in Pa, or null if invalid
  Hc20Baro1mPoint(
      super.slot, super.minuteOfDay, super.timeHHMM, super.valid, this.pascals);
}

class Hc20Bp5mPoint extends Hc20DataPoint {
  final int? sys; // systolic pressure, or null if invalid
  final int? dia; // diastolic pressure, or null if invalid
  Hc20Bp5mPoint(super.slot, super.minuteOfDay, super.timeHHMM, super.valid,
      this.sys, this.dia);
}

class Hc20Hrv5mPoint extends Hc20DataPoint {
  final double? sdnn; // SDNN, or null if invalid
  final double? tp; // Total Power, or null if invalid
  final double? lf; // Low Frequency, or null if invalid
  final double? hf; // High Frequency, or null if invalid
  final double? vlf; // Very Low Frequency, or null if invalid
  Hc20Hrv5mPoint(super.slot, super.minuteOfDay, super.timeHHMM, super.valid,
      this.sdnn, this.tp, this.lf, this.hf, this.vlf);
}

class Hc20Gnss1mPoint extends Hc20DataPoint {
  final double? lat; // latitude, or null if invalid
  final double? lon; // longitude, or null if invalid
  final int? signal; // signal strength, or null if invalid
  Hc20Gnss1mPoint(super.slot, super.minuteOfDay, super.timeHHMM, super.valid,
      this.lat, this.lon, this.signal);
}

class Hc20Calories5mPoint extends Hc20DataPoint {
  final int? kcal; // calories in kcal, or null if invalid
  Hc20Calories5mPoint(
      super.slot, super.minuteOfDay, super.timeHHMM, super.valid, this.kcal);
}

class Hc20Hrv2_5mPoint extends Hc20DataPoint {
  final int? mentalStress; // mental stress, or null if invalid
  final int? fatigueLevel; // fatigue level, or null if invalid
  final int? stressResistance; // stress resistance, or null if invalid
  final int? regulationAbility; // regulation ability, or null if invalid
  Hc20Hrv2_5mPoint(
      super.slot,
      super.minuteOfDay,
      super.timeHHMM,
      super.valid,
      this.mentalStress,
      this.fatigueLevel,
      this.stressResistance,
      this.regulationAbility);
}

// Container classes for enhanced data
class Hc20Heart5s {
  final List<Hc20Heart5sPoint> points;
  Hc20Heart5s(this.points);
}

class Hc20Steps5m {
  final List<Hc20Steps5mPoint> points;
  Hc20Steps5m(this.points);
}

class Hc20Spo25m {
  final List<Hc20Spo25mPoint> points;
  Hc20Spo25m(this.points);
}

class Hc20Rri5s {
  final List<Hc20Rri5sPoint> points;
  Hc20Rri5s(this.points);
}

class Hc20Temp1m {
  final List<Hc20Temp1mPoint> points;
  Hc20Temp1m(this.points);
}

class Hc20Baro1m {
  final List<Hc20Baro1mPoint> points;
  Hc20Baro1m(this.points);
}

class Hc20Bp5m {
  final List<Hc20Bp5mPoint> points;
  Hc20Bp5m(this.points);
}

class Hc20Hrv5m {
  final List<Hc20Hrv5mPoint> points;
  Hc20Hrv5m(this.points);
}

class Hc20Gnss1m {
  final List<Hc20Gnss1mPoint> points;
  Hc20Gnss1m(this.points);
}

class Hc20Calories5m {
  final List<Hc20Calories5mPoint> points;
  Hc20Calories5m(this.points);
}

class Hc20Hrv2_5m {
  final List<Hc20Hrv2_5mPoint> points;
  Hc20Hrv2_5m(this.points);
}

class Hc20SleepDetails {
  final List<Hc20SleepDetail> details;
  Hc20SleepDetails(this.details);
}
