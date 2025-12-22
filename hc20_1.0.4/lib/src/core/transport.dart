import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'ble_adapter.dart';
import 'errors.dart';
import 'frame.dart';
import 'response_parser.dart';

abstract class IHc20Transport {
  Future<Hc20Frame> request(String deviceId, int func, List<int> payload);
  Stream<Hc20Frame> notifications(String deviceId, {bool forceReconnect = false});
  Stream<Hc20Message> notificationsParsed(String deviceId, {bool forceReconnect = false});
  Future<void> dispose();
}

class Hc20Transport implements IHc20Transport {
  final Hc20BleAdapter ble;
  final _streams = <String, StreamSubscription<List<int>>>{};
  final _controllers = <String, StreamController<Hc20Frame>>{};
  final _parsedControllers = <String, StreamController<Hc20Message>>{};

  Hc20Transport(this.ble);

  void _ensureStreams(String deviceId, {bool forceReconnect = false}) {
    // If streams already exist and we're not forcing reconnect, return
    if (_controllers.containsKey(deviceId) && !forceReconnect) return;
    
    // If forcing reconnect, clean up old subscription
    if (forceReconnect && _streams.containsKey(deviceId)) {
      _streams[deviceId]?.cancel();
      _streams.remove(deviceId);
    }
    
    // Create new controllers if they don't exist or if forcing reconnect
    if (!_controllers.containsKey(deviceId) || forceReconnect) {
      // Close old controllers if forcing reconnect
      if (forceReconnect) {
        _controllers[deviceId]?.close();
        _parsedControllers[deviceId]?.close();
      }
      
      final ctrl = StreamController<Hc20Frame>.broadcast();
      final parsedCtrl = StreamController<Hc20Message>.broadcast();
      _controllers[deviceId] = ctrl;
      _parsedControllers[deviceId] = parsedCtrl;
    } else {
      // Controllers already exist, just return
      return;
    }

    final buffer = BytesBuilder();
    final sub = ble.subscribe(deviceId, ble.ids.serviceFff0, ble.ids.charFff1).listen((chunk) {
      buffer.add(chunk);
      // Log raw notification chunk (HEX)
      // ignore: avoid_print
      //print('HC20 RX chunk device=$deviceId bytes=' + chunk.map((b)=>b.toRadixString(16).padLeft(2,'0')).join(' '));
      final bytes = buffer.toBytes();
      final result = Hc20Codec.decodeMany(Uint8List.fromList(bytes));
      final frames = result.frames;
      final consumedBytes = result.consumedBytes;
      
      if (frames.isNotEmpty) {
        // Remove only the consumed bytes from buffer, preserving any incomplete frame
        if (consumedBytes > 0) {
          final remaining = bytes.sublist(consumedBytes);
          buffer.clear();
          buffer.add(remaining);
        }
        
        for (final f in frames) {
          // ignore: avoid_print
          //final payloadHex = f.payload.map((b)=>b.toRadixString(16).padLeft(2,'0')).join(' ');
          //print('HC20 RX frame device=$deviceId func=0x' + f.func.toRadixString(16) + ' len=' + f.payload.length.toString() + ' payload=' + payloadHex);
          _controllers[deviceId]?.add(f);
          // Parse immediately so parsing side-effects (debug logs) run inside plugin
          final msg = Hc20ResponseParser.parse(f);
          _parsedControllers[deviceId]?.add(msg);
        }
      } else if (bytes.length > 4096) {
        // Only clear if buffer gets too large (safety measure)
        // But try to find a header and keep from there
        final headerIndex = bytes.lastIndexOf(0x68);
        if (headerIndex > 0 && headerIndex < bytes.length - 6) {
          // Keep from last header in case it's part of a frame
          final remaining = bytes.sublist(headerIndex);
          buffer.clear();
          buffer.add(remaining);
        } else {
          buffer.clear();
        }
      }
    });
    _streams[deviceId] = sub;
  }

  @override
  Stream<Hc20Frame> notifications(String deviceId, {bool forceReconnect = false}) {
    _ensureStreams(deviceId, forceReconnect: forceReconnect);
    return _controllers[deviceId]!.stream;
  }

  Stream<Hc20Message> notificationsParsed(String deviceId, {bool forceReconnect = false}) {
    _ensureStreams(deviceId, forceReconnect: forceReconnect);
    return _parsedControllers[deviceId]!.stream;
  }

  @override
  Future<Hc20Frame> request(String deviceId, int func, List<int> payload) async {
    final bytes = Hc20Codec.encode(func, payload);
    final respCode = (func | 0x80) & 0xFF;

    final completer = Completer<Hc20Frame>();
    late StreamSubscription sub;
    sub = notifications(deviceId).where((f) => f.func == respCode || (f.func & 0x40) != 0).listen((f) {
      if ((f.func & 0x40) != 0) {
        final jsonStart = f.payload.indexWhere((b) => b == 0x7B);
        final jsonEnd = f.payload.lastIndexWhere((b) => b == 0x7D);
        final jsonStr = (jsonStart >= 0 && jsonEnd > jsonStart)
            ? utf8.decode(f.payload.sublist(jsonStart, jsonEnd + 1))
            : '{"code":192,"msg":"exception"}';
        final map = json.decode(jsonStr) as Map<String, dynamic>;
        sub.cancel();
        completer.completeError(Hc20Exception(map['code'] ?? 0xC0, map['msg']?.toString() ?? 'exception'));
        return;
      }
      if (f.func == respCode) {
        sub.cancel();
        completer.complete(f);
      }
    });
    await ble.write(deviceId, ble.ids.serviceFff0, ble.ids.charFff2, bytes);
    return completer.future;
  }

  @override
  Future<void> dispose() async {
    for (final s in _streams.values) { await s.cancel(); }
    for (final c in _controllers.values) { await c.close(); }
    for (final c in _parsedControllers.values) { await c.close(); }
    _streams.clear(); _controllers.clear();
    _parsedControllers.clear();
  }
}

List<int> jsonPayload(int fixed, Map<String, dynamic> map) {
  final b = <int>[fixed];
  b.addAll(utf8.encode(json.encode(map)));
  b.add(0x00);
  return b;
}


