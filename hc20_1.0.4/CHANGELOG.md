## 1.0.0 (20 November 2025)

* Initial release.

## 1.0.2 (04 December 2025)
* Modify enable raw sensor and temporary disable raw sensor logic.

## 1.0.4 (19 Dec 2025)
* Add skin temperature upload feature - automatically uploads all-day temperature data (skin and ambient temperature) to cloud when fetching temperature history data.
* Add automatic reconnection feature - implements exponential backoff reconnection strategy with periodic reconnection attempts to handle device disconnections and out-of-range scenarios.
* Add connection state stream - provides real-time connection state updates (connected, reconnected, disconnected) through `connectionState` stream to differentiate between initial connections and reconnections.
