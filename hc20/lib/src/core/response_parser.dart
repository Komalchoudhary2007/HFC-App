import 'dart:convert';
import 'dart:typed_data';
import 'frame.dart';
import '../models/processed_models.dart';
import '../raw/config.dart';

abstract class Hc20Message {}

class Hc20MsgException extends Hc20Message {
  final int code;
  final String msg;
  Hc20MsgException(this.code, this.msg);
}

class Hc20MsgDeviceInfo extends Hc20Message {
  final Hc20DeviceInfo info;
  Hc20MsgDeviceInfo(this.info);
}

class Hc20MsgParams extends Hc20Message {
  final int kind; // 0x01 set, 0x02 get
  final Map<String, dynamic> data; // JSON content
  Hc20MsgParams(this.kind, this.data);
}

class Hc20MsgTime extends Hc20Message {
  final int kind; // 0x01 set, 0x02 get
  final Hc20Time time;
  Hc20MsgTime(this.kind, this.time);
}

class Hc20MsgRealtimeV2 extends Hc20Message {
  final Hc20RealtimeV2 rt;
  Hc20MsgRealtimeV2(this.rt);
}

class Hc20MsgHistory extends Hc20Message {
  final int type; // 0x00..0x0C, 0xFD, 0xFE
  final int yy, mm, dd;
  final int index, total;
  final Uint8List data; // raw data part after headers
  Hc20MsgHistory(this.type, this.yy, this.mm, this.dd, this.index, this.total, this.data);
}

class Hc20ResponseParser {
  static Hc20Message parse(Hc20Frame f) {
    final func = f.func;
    final p = f.payload;
    if ((func & 0x40) != 0) {
      // Exception frame may contain a leading instruction byte before JSON
      final j = _jsonFromPayloadFindJson(p);
      return Hc20MsgException(j['code'] ?? 0xC0, j['msg']?.toString() ?? 'exception');
    }
    switch (func) {
      case 0x9F:
        final jsonData = _jsonFromPayloadSkipLead(p, 1);
        Hc20CloudConfig.debugPrint('HC20 DEBUG: Device Info JSON payload: $jsonData');
        return Hc20MsgDeviceInfo(Hc20DeviceInfo.fromJson(jsonData));
      case 0x82:
        if (p.isEmpty) return Hc20MsgParams(0, const {});
        final kind = p[0];
        if (kind == 0x02 && p.length > 1) {
          final jsonData = _jsonFromPayloadSkipLead(p, 1);
          Hc20CloudConfig.debugPrint('HC20 DEBUG: Params JSON payload: $jsonData');
          return Hc20MsgParams(kind, jsonData);
        } else {
          // ACK for set (0x01), no JSON present
          Hc20CloudConfig.debugPrint('HC20 DEBUG: Params ACK kind=0x${kind.toRadixString(16)} (no JSON)');
          return Hc20MsgParams(kind, const {});
        }
      case 0x84:
        if (p.isEmpty) return Hc20MsgTime(0, Hc20Time(0, 8));
        final kind = p[0];
        if (kind == 0x02 && p.length > 1) {
          final j = _jsonFromPayloadSkipLead(p, 1);
          Hc20CloudConfig.debugPrint('HC20 DEBUG: Time JSON payload: $j');
          return Hc20MsgTime(kind, Hc20Time(j['timestamp'] ?? 0, j['timezone'] ?? 8));
        } else {
          // ACK for set (0x01), no JSON present
          Hc20CloudConfig.debugPrint('HC20 DEBUG: Time ACK kind=0x${kind.toRadixString(16)} (no JSON)');
          return Hc20MsgTime(kind, Hc20Time(0, 8));
        }
      case 0x85:
        final jsonData = _jsonFromPayloadSkipLead(p, 1);
        Hc20CloudConfig.debugPrint('HC20 DEBUG: RealtimeV2 JSON payload: $jsonData');
        return Hc20MsgRealtimeV2(Hc20RealtimeV2.fromMap(jsonData));
      case 0x97:
        if (p.isEmpty) return Hc20MsgHistory(0, 0, 0, 0, 0, 0, Uint8List(0));
        // Special formats: 0xFD (packet status), 0xFE (storage info)
        if (p[0] == 0xFD) {
          // Format: 0xFD, type, yy, mm, dd, statuses...
          if (p.length < 5) return Hc20MsgHistory(0xFD, 0, 0, 0, 0, 0, Uint8List(0));
          final yy = p[2];
          final mm = p[3];
          final dd = p[4];
          return Hc20MsgHistory(0xFD, yy, mm, dd, 0, 0, Uint8List.fromList(p));
        }
        if (p[0] == 0xFE) {
          // Format: 0xFE + JSON + 0x00
          return Hc20MsgHistory(0xFE, 0, 0, 0, 0, 0, Uint8List.fromList(p));
        }
        if (p.length < 8) return Hc20MsgHistory(0, 0, 0, 0, 0, 0, Uint8List(0));
        final type = p[0];
        final yy = p[1];
        final mm = p[2];
        final dd = p[3];
        final idx = p[4] | (p[5] << 8);
        final total = p[6] | (p[7] << 8);
        final data = Uint8List.fromList(p.sublist(8));
        return Hc20MsgHistory(type, yy, mm, dd, idx, total, data);
      default:
        return Hc20MsgException(0x01, 'unsupported function 0x${func.toRadixString(16)}');
    }
  }

  static Map<String, dynamic> _jsonFromPayload(Uint8List p) {
    final s = utf8.decode(p);
    return json.decode(s) as Map<String, dynamic>;
  }

  static Map<String, dynamic> _jsonFromPayloadSkipLead(Uint8List p, int skip) {
    final end = p.lastIndexOf(0x00);
    final slice = end > skip ? p.sublist(skip, end) : p.sublist(skip);
    final s = utf8.decode(slice);
    return json.decode(s) as Map<String, dynamic>;
  }

  static Map<String, dynamic> _jsonFromPayloadFindJson(Uint8List p) {
    final l = p.indexOf(0x7B); // '{'
    final r = p.lastIndexOf(0x7D); // '}'
    if (l >= 0 && r > l) {
      final s = utf8.decode(p.sublist(l, r + 1));
      try { return json.decode(s) as Map<String, dynamic>; } catch (_) {}
    }
    return const {};
  }
}


