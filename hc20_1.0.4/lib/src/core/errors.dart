class Hc20Exception implements Exception {
  final int code;
  final String message;
  Hc20Exception(this.code, this.message);
  @override
  String toString() => 'Hc20Exception(code=0x${code.toRadixString(16)}, msg=$message)';
}

class Hc20TimeoutException implements Exception {
  final String operation;
  Hc20TimeoutException(this.operation);
  @override
  String toString() => 'Hc20TimeoutException($operation)';
}


