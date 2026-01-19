package com.example.hfc_app

import android.util.Log
import org.json.JSONObject
import java.nio.ByteBuffer
import java.nio.ByteOrder

/**
 * HC20 Protocol Implementation
 * 
 * This is a native Kotlin port of the HC20 SDK protocol.
 * Based on analysis of hc20_1.0.4/lib/src/core/frame.dart and response_parser.dart
 * 
 * Frame Format:
 * - Header: 0x68
 * - Function Code: 1 byte
 * - Length: 2 bytes (little-endian)
 * - Payload: N bytes
 * - Checksum: 1 byte (sum of all bytes from header to end of payload)
 * - Tail: 0x16
 * 
 * Key Function Codes (Response = Request | 0x80):
 * - 0x1F -> 0x9F: Device Info
 * - 0x02 -> 0x82: Parameters
 * - 0x04 -> 0x84: Time
 * - 0x05 -> 0x85: Realtime V2 Data (heart rate, SPO2, temperature, etc.)
 * - 0x30 -> 0xB0: Raw Sensor Data (IMU, PPG, GSR)
 * - 0x17 -> 0x97: Historical Data
 */
object HC20Protocol {
    private const val TAG = "HC20Protocol"
    
    // Frame constants
    const val FRAME_HEADER: Byte = 0x68
    const val FRAME_TAIL: Byte = 0x16
    
    // BLE Service/Characteristic UUIDs (from ble_adapter.dart)
    const val SERVICE_FFF0 = "0000FFF0-0000-1000-8000-00805F9B34FB"
    const val CHAR_FFF1 = "0000FFF1-0000-1000-8000-00805F9B34FB"  // Notifications (receive)
    const val CHAR_FFF2 = "0000FFF2-0000-1000-8000-00805F9B34FB"  // Write commands
    
    // Standard Heart Rate Service (alternative)
    const val SERVICE_HEART_RATE = "0000180D-0000-1000-8000-00805F9B34FB"
    const val CHAR_HEART_RATE = "00002A37-0000-1000-8000-00805F9B34FB"
    
    // Client Characteristic Configuration Descriptor (for enabling notifications)
    const val CCCD_UUID = "00002902-0000-1000-8000-00805F9B34FB"
    
    // Function codes (Request)
    const val FUNC_DEVICE_INFO: Byte = 0x1F
    const val FUNC_PARAMS: Byte = 0x02
    const val FUNC_TIME: Byte = 0x04
    const val FUNC_REALTIME_V2: Byte = 0x05
    const val FUNC_SENSOR_RAW: Byte = 0x30
    const val FUNC_HISTORY: Byte = 0x17
    
    // Response codes (Request | 0x80)
    const val RESP_DEVICE_INFO: Byte = 0x9F.toByte()
    const val RESP_PARAMS: Byte = 0x82.toByte()
    const val RESP_TIME: Byte = 0x84.toByte()
    const val RESP_REALTIME_V2: Byte = 0x85.toByte()
    const val RESP_SENSOR_RAW: Byte = 0xB0.toByte()
    const val RESP_HISTORY: Byte = 0x97.toByte()
    
    // Manufacturer data identifiers for HC20 devices
    const val HC20_BROADCAST_ID: Byte = 0xB8.toByte()
    const val HC20_RESPONSE_B6: Byte = 0xB6.toByte()
    const val HC20_RESPONSE_B7: Byte = 0xB7.toByte()
    
    /**
     * Represents a decoded HC20 frame
     */
    data class HC20Frame(
        val func: Int,
        val payload: ByteArray
    ) {
        override fun equals(other: Any?): Boolean {
            if (this === other) return true
            if (javaClass != other?.javaClass) return false
            other as HC20Frame
            return func == other.func && payload.contentEquals(other.payload)
        }
        
        override fun hashCode(): Int {
            var result = func
            result = 31 * result + payload.contentHashCode()
            return result
        }
    }
    
    /**
     * Parsed realtime health data - matches Flutter Hc20RealtimeV2
     */
    data class RealtimeData(
        val heartRate: Int? = null,
        val spo2: Int? = null,
        val rri: Int? = null,
        val bloodPressure: Pair<Int, Int>? = null, // systolic, diastolic
        val temperature: List<Int>? = null, // [hand, env, body] (x100)
        val batteryPercent: Int? = null,
        val batteryCharging: Int? = null, // 0, 1, 2
        val steps: Int? = null,
        val calories: Int? = null,
        val distance: Int? = null,
        val wear: Int? = null, // wear status
        val baro: Int? = null, // barometric pressure
        val sleep: List<Int>? = null, // [status, deep, light, rem, sober]
        val gnss: List<Int>? = null, // [onoff, sigqual, timestamp, lat, lon, alt]
        val hrv: List<Int>? = null, // [SDNN, TP, LF, HF, VLF] values x1000
        val hrv2: List<Int>? = null, // [mental_stress, fatigue, stress_resistance, regulation_ability]
        val timestamp: Long = System.currentTimeMillis()
    ) {
        // Get temperature in Celsius (divided by 100)
        val temperatureInCelsius: List<Double>?
            get() = temperature?.map { it / 100.0 }
        
        val bodyTemperature: Double?
            get() = temperature?.getOrNull(2)?.let { it / 100.0 }
        
        // HRV metrics helper
        data class HrvMetrics(
            val sdnn: Int,
            val tp: Int,
            val lf: Int,
            val hf: Int,
            val vlf: Int
        )
        
        val hrvMetrics: HrvMetrics?
            get() = hrv?.let {
                if (it.size >= 5) HrvMetrics(it[0], it[1], it[2], it[3], it[4]) else null
            }
        
        // HRV2 metrics helper
        data class Hrv2Metrics(
            val mentalStress: Int,
            val fatigueLevel: Int,
            val stressResistance: Int,
            val regulationAbility: Int
        )
        
        val hrv2Metrics: Hrv2Metrics?
            get() = hrv2?.let {
                if (it.size >= 4) Hrv2Metrics(it[0], it[1], it[2], it[3]) else null
            }
    }
    
    /**
     * Device information
     */
    data class DeviceInfo(
        val name: String,
        val mac: String,
        val version: String,
        val versionTag: String? = null,
        val buildTime: String? = null
    )
    
    /**
     * Encode a command frame to send to HC20
     */
    fun encodeCommand(func: Byte, payload: ByteArray = ByteArray(0)): ByteArray {
        val length = payload.size
        val buffer = ByteBuffer.allocate(1 + 1 + 2 + length + 1 + 1)
            .order(ByteOrder.LITTLE_ENDIAN)
        
        buffer.put(FRAME_HEADER)
        buffer.put(func)
        buffer.putShort(length.toShort())
        buffer.put(payload)
        
        // Calculate checksum (sum of all bytes so far)
        val dataToChecksum = buffer.array().sliceArray(0 until (4 + length))
        val checksum = dataToChecksum.fold(0) { acc, b -> (acc + (b.toInt() and 0xFF)) and 0xFF }
        
        buffer.put(checksum.toByte())
        buffer.put(FRAME_TAIL)
        
        return buffer.array()
    }
    
    /**
     * Encode a JSON payload command
     */
    fun encodeJsonCommand(func: Byte, fixedByte: Byte, jsonData: Map<String, Any>): ByteArray {
        val jsonStr = JSONObject(jsonData).toString()
        Log.d(TAG, "🔧 BUILDING COMMAND:")
        Log.d(TAG, "🔧   Function code: 0x${func.toString(16)}")
        Log.d(TAG, "🔧   Fixed byte: 0x${fixedByte.toString(16)}")
        Log.d(TAG, "🔧   JSON config: $jsonStr")
        
        val jsonBytes = jsonStr.toByteArray(Charsets.UTF_8)
        val payload = ByteArray(1 + jsonBytes.size + 1)
        payload[0] = fixedByte
        System.arraycopy(jsonBytes, 0, payload, 1, jsonBytes.size)
        payload[payload.size - 1] = 0x00 // null terminator
        
        val result = encodeCommand(func, payload)
        Log.d(TAG, "🔧   Final command: ${bytesToHex(result)}")
        return result
    }
    
    /**
     * Create "Enable Sensors" command
     * Based on setSensorState in hc20_client.dart
     */
    fun createEnableSensorsCommand(): ByteArray {
        // 0x05 = realtime data, enable all sensors
        // Payload format: 0x01 + JSON config
        val config = mapOf(
            "basic_data" to 1,
            "heart" to 1,
            "spo2" to 1,
            "bp" to 1,
            "temperature" to 1,
            "baro" to 1,
            "wear" to 1,
            "gnss" to 1,
            "hrv" to 1,
            "hrv2" to 1,
            "rri" to 1,
            "battery" to 1
        )
        return encodeJsonCommand(FUNC_REALTIME_V2, 0x01, config)
    }
    
    /**
     * Create HRV2-ONLY enable command (for minimal testing)
     * This focuses only on getting hrv2_metrics data
     */
    fun createEnableHrv2OnlyCommand(): ByteArray {
        // MINIMAL: Only enable heart (required baseline) and hrv2
        val config = mapOf(
            "heart" to 1,
            "hrv2" to 1,
            "battery" to 1
        )
        return encodeJsonCommand(FUNC_REALTIME_V2, 0x01, config)
    }
    
    /**
     * Create "Get Device Info" command
     */
    fun createGetDeviceInfoCommand(): ByteArray {
        return encodeCommand(FUNC_DEVICE_INFO, ByteArray(0))
    }
    
    /**
     * Create "Set Time" command
     */
    fun createSetTimeCommand(timestampSeconds: Long, timezone: Int = 8): ByteArray {
        val config = mapOf(
            "timestamp" to timestampSeconds,
            "timezone" to timezone
        )
        return encodeJsonCommand(FUNC_TIME, 0x01, config)
    }
    
    /**
     * Decode result containing frames and consumed byte count
     */
    data class DecodeResult(
        val frames: List<HC20Frame>,
        val consumedBytes: Int
    )
    
    /**
     * Decode one or more frames from a buffer
     * Handles partial frames by returning how many bytes were consumed
     */
    fun decode(buffer: ByteArray): DecodeResult {
        val frames = mutableListOf<HC20Frame>()
        var i = 0
        
        while (i + 6 <= buffer.size) {
            // Look for header
            if (buffer[i] != FRAME_HEADER) {
                i++
                continue
            }
            
            // Read function code and length
            val func = buffer[i + 1].toInt() and 0xFF
            val len = (buffer[i + 2].toInt() and 0xFF) or ((buffer[i + 3].toInt() and 0xFF) shl 8)
            
            // Calculate frame end position
            val endExclusive = i + 1 + 1 + 2 + len + 1 + 1
            if (endExclusive > buffer.size) break // Need more data
            
            // Validate tail
            val tailIndex = endExclusive - 1
            if (buffer[tailIndex] != FRAME_TAIL) {
                i++
                continue
            }
            
            // Validate checksum
            val csIndex = endExclusive - 2
            val expectedCs = buffer[csIndex].toInt() and 0xFF
            val calculatedCs = buffer.sliceArray(i until csIndex)
                .fold(0) { acc, b -> (acc + (b.toInt() and 0xFF)) and 0xFF }
            
            if (expectedCs != calculatedCs) {
                Log.w(TAG, "Checksum mismatch: expected $expectedCs, got $calculatedCs")
                i++
                continue
            }
            
            // Extract payload
            val payload = buffer.sliceArray(i + 4 until i + 4 + len)
            frames.add(HC20Frame(func, payload))
            
            i = endExclusive
        }
        
        return DecodeResult(frames, i)
    }
    
    /**
     * Parse a realtime V2 data frame (func 0x85)
     */
    fun parseRealtimeV2(frame: HC20Frame): RealtimeData? {
        if (frame.func != (RESP_REALTIME_V2.toInt() and 0xFF)) {
            Log.w(TAG, "Not a realtime V2 frame: func=0x${frame.func.toString(16)}")
            return null
        }
        
        val payload = frame.payload
        if (payload.isEmpty()) return null
        
        try {
            // Skip first byte (instruction) and parse JSON
            // Find JSON start and end
            val jsonStart = payload.indexOfFirst { it == '{'.code.toByte() }
            val jsonEnd = payload.indexOfLast { it == '}'.code.toByte() }
            
            if (jsonStart < 0 || jsonEnd <= jsonStart) {
                Log.w(TAG, "No JSON found in realtime payload")
                return null
            }
            
            val jsonStr = String(payload.sliceArray(jsonStart..jsonEnd), Charsets.UTF_8)
            val json = JSONObject(jsonStr)
            
            Log.d(TAG, "\n🔍 ====== REALTIME JSON RECEIVED ======")
            Log.d(TAG, "🔍 Raw JSON: $jsonStr")
            Log.d(TAG, "🔍 JSON keys: ${json.keys().asSequence().toList()}")
            Log.d(TAG, "🔍 Has bp: ${json.has("bp")}")
            Log.d(TAG, "🔍 Has temperature: ${json.has("temperature")}")
            Log.d(TAG, "🔍 Has basic_data: ${json.has("basic_data")}")
            Log.d(TAG, "🔍 Has hrv: ${json.has("hrv")}")
            Log.d(TAG, "🔍 Has hrv2: ${json.has("hrv2")}")
            Log.d(TAG, "🔍 ====================================\n")
            
            // Parse battery: "percent,charging"
            var batteryPercent: Int? = null
            var batteryCharging: Int? = null
            if (json.has("battery")) {
                val batteryStr = json.optString("battery", "")
                val parts = batteryStr.split(",")
                if (parts.isNotEmpty()) batteryPercent = parts[0].trim().toIntOrNull()
                if (parts.size > 1) batteryCharging = parts[1].trim().toIntOrNull()
            }
            
            // Parse basic_data: "steps,calories,distance"
            var steps: Int? = null
            var calories: Int? = null
            var distance: Int? = null
            if (json.has("basic_data")) {
                val basicStr = json.optString("basic_data", "")
                val parts = basicStr.split(",")
                if (parts.isNotEmpty()) steps = parts[0].trim().toIntOrNull()
                if (parts.size > 1) calories = parts[1].trim().toIntOrNull()
                if (parts.size > 2) distance = parts[2].trim().toIntOrNull()
            }
            
            // Parse temperature: "hand,env,body" (all x100)
            var temperature: List<Int>? = null
            if (json.has("temperature")) {
                val tempStr = json.optString("temperature", "")
                val parts = tempStr.split(",")
                temperature = parts.mapNotNull { it.trim().toIntOrNull() }
            }
            
            // Parse blood pressure: "systolic,diastolic"
            var bp: Pair<Int, Int>? = null
            if (json.has("bp")) {
                val bpStr = json.optString("bp", "")
                val parts = bpStr.split(",")
                if (parts.size >= 2) {
                    val sys = parts[0].trim().toIntOrNull()
                    val dia = parts[1].trim().toIntOrNull()
                    if (sys != null && dia != null) {
                        bp = Pair(sys, dia)
                    }
                }
            }
            
            // Parse baro (barometric pressure)
            val baro = json.optInt("baro", -1).takeIf { it > 0 }
            
            // Parse sleep: "status,deep,light,rem,sober"
            var sleep: List<Int>? = null
            if (json.has("sleep")) {
                val sleepStr = json.optString("sleep", "")
                val parts = sleepStr.split(",")
                sleep = parts.mapNotNull { it.trim().toIntOrNull() }
            }
            
            // Parse gnss: "onoff,sigqual,timestamp,lat,lon,alt"
            var gnss: List<Int>? = null
            if (json.has("gnss")) {
                val gnssStr = json.optString("gnss", "")
                val parts = gnssStr.split(",")
                gnss = parts.mapNotNull { it.trim().toIntOrNull() }
            }
            
            // Parse hrv: "SDNN,TP,LF,HF,VLF" (values x1000)
            var hrv: List<Int>? = null
            if (json.has("hrv")) {
                val hrvStr = json.optString("hrv", "")
                val parts = hrvStr.split(",")
                hrv = parts.mapNotNull { it.trim().toIntOrNull() }
            }
            
            // Parse hrv2: "mental_stress,fatigue,stress_resistance,regulation_ability"
            var hrv2: List<Int>? = null
            if (json.has("hrv2")) {
                val hrv2Str = json.optString("hrv2", "")
                Log.d(TAG, "🔍 HRV2 STRING FROM DEVICE: '$hrv2Str'")
                val parts = hrv2Str.split(",")
                Log.d(TAG, "🔍 HRV2 PARTS: $parts")
                hrv2 = parts.mapNotNull { it.trim().toIntOrNull() }
                Log.d(TAG, "🔍 HRV2 PARSED: $hrv2")
            } else {
                Log.w(TAG, "⚠️⚠️⚠️ HRV2 KEY NOT FOUND IN JSON!")
                Log.w(TAG, "⚠️⚠️⚠️ This means device is NOT sending hrv2 data!")
                Log.w(TAG, "⚠️⚠️⚠️ Enable command may not be working!")
            }
            
            return RealtimeData(
                heartRate = json.optInt("heart", -1).takeIf { it > 0 },
                spo2 = json.optInt("spo2", -1).takeIf { it > 0 },
                rri = json.optInt("rri", -1).takeIf { it > 0 },
                bloodPressure = bp,
                temperature = temperature,
                batteryPercent = batteryPercent,
                batteryCharging = batteryCharging,
                steps = steps,
                calories = calories,
                distance = distance,
                wear = json.optInt("wear", -1).takeIf { it >= 0 },
                baro = baro,
                sleep = sleep,
                gnss = gnss,
                hrv = hrv,
                hrv2 = hrv2
            )
            
        } catch (e: Exception) {
            Log.e(TAG, "Error parsing realtime V2: ${e.message}", e)
            return null
        }
    }
    
    /**
     * Parse device info frame (func 0x9F)
     */
    fun parseDeviceInfo(frame: HC20Frame): DeviceInfo? {
        if (frame.func != (RESP_DEVICE_INFO.toInt() and 0xFF)) return null
        
        try {
            val payload = frame.payload
            if (payload.isEmpty()) return null
            
            // Skip first byte, parse JSON
            val jsonStart = payload.indexOfFirst { it == '{'.code.toByte() }
            val jsonEnd = payload.indexOfLast { it == '}'.code.toByte() }
            
            if (jsonStart < 0 || jsonEnd <= jsonStart) return null
            
            val jsonStr = String(payload.sliceArray(jsonStart..jsonEnd), Charsets.UTF_8)
            val json = JSONObject(jsonStr)
            
            return DeviceInfo(
                name = json.optString("name", ""),
                mac = json.optString("mac", ""),
                version = json.optString("version", ""),
                versionTag = json.optString("version_tag", null),
                buildTime = json.optString("build_time", null)
            )
            
        } catch (e: Exception) {
            Log.e(TAG, "Error parsing device info: ${e.message}", e)
            return null
        }
    }
    
    /**
     * Check if manufacturer data indicates an HC20 device
     * Based on _isHc20Adv in ble_adapter.dart
     */
    fun isHC20ManufacturerData(data: ByteArray): Boolean {
        if (data.isEmpty()) return false
        
        // Check for broadcast format (0xB8)
        if (data.any { it == HC20_BROADCAST_ID }) return true
        
        // Check for FF B8 pattern
        for (i in 0 until data.size - 1) {
            if (data[i] == 0xFF.toByte() && data[i + 1] == HC20_BROADCAST_ID) {
                return true
            }
        }
        
        // Check for response broadcast format (0xB6 and 0xB7)
        val hasB6 = data.any { it == HC20_RESPONSE_B6 }
        val hasB7 = data.any { it == HC20_RESPONSE_B7 }
        if (hasB6 && hasB7) {
            val b6Index = data.indexOfFirst { it == HC20_RESPONSE_B6 }
            val b7Index = data.indexOfFirst { it == HC20_RESPONSE_B7 }
            if (b6Index >= 0 && b7Index > b6Index) return true
        }
        
        return false
    }
    
    /**
     * Check if device name looks like an HC20
     */
    fun isHC20DeviceName(name: String?): Boolean {
        if (name.isNullOrEmpty()) return false
        val lowerName = name.lowercase()
        return lowerName.contains("b20") || 
               lowerName.contains("hc-20") || 
               lowerName.contains("hc20")
    }
    
    /**
     * Convert bytes to hex string for debugging
     */
    fun bytesToHex(bytes: ByteArray): String {
        return bytes.joinToString(" ") { "%02X".format(it) }
    }
}
