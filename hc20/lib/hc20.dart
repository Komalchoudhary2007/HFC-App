library hc20;

// Export all processed models that clients need
// This includes all data models, enums, and extensions that clients interact with
export 'src/models/processed_models.dart';

// Export raw sensor data models (client-facing only)
export 'src/models/raw_models.dart'
    show
        Hc20ImuData,
        Hc20AccelerometerData,
        Hc20GyroscopeData,
        Hc20MagnetometerData,
        Hc20PpgData,
        Hc20GsrData,
        Hc20SensorConfig,
        Hc20ImuConfig,
        Hc20PpgConfig,
        Hc20EcgConfig,
        Hc20GsrConfig,
        Hc20SensorState,
        Hc20ImuState,
        Hc20PpgState,
        Hc20EcgState,
        Hc20GsrState;

// Export the main client API - this is the only entry point clients should use
export 'src/processed/hc20_client.dart'
    show Hc20Client, Hc20Config, Hc20ScanFilter;

// Internal implementation details are NOT exported:
// - response_parser.dart (packet decoding logic)
// - ble_adapter.dart (BLE characteristic handling)
// - transport.dart (frame encoding/decoding)
// - raw_manager.dart (raw data upload)
// - Internal raw_models.dart classes (ImuSample, PpgSample, GsrSample)
