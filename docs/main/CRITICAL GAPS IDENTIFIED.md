CRITICAL ANALYSIS: Device Disconnect Detection & UI Update Issues
Based on your manual testing results and code analysis, I've identified 7 MAJOR GAPS in the current implementation:

🔴 CRITICAL GAPS IDENTIFIED
Gap #1: Connection Monitoring Timeout Too Long (12 minutes)
Location: main.dart:963-989

Problem:

Current monitoring checks every 30 seconds but only triggers disconnect after 720 seconds (12 minutes) of no data
Your webhook sends data every 120 seconds (2 minutes)
Device disconnect should be detected after ~4-5 minutes (2-3 missed webhook cycles)
Evidence from testing:

6:06:35 = Last data received
6:08:34, 6:10:34, 6:12:34 = No data but UI still shows "Connected"
6:19:17 = Reconnected (13 minutes gap!)
Fix Required:

Gap #2: _isConnected Flag Not Updated on Stream Errors
Location: main.dart:802-817

Problem:

When realtimeV2 stream throws error (device disconnect, out of range, bluetooth off), the _isConnected flag is NOT updated to false
Only _statusMessage is updated
UI continues showing "Connected" because it checks _isConnected flag
Evidence from testing:

Device shutdown/out of range/bluetooth off → UI keeps showing "Connected"
Status message might update but connection icon stays green
Fix Required:

Gap #3: No Active Bluetooth Connection State Check
Location: main.dart:967-989

Problem:

Monitoring only checks timestamp of last received data
Does NOT actively check if Bluetooth connection is still alive
Cannot detect instant disconnects (bluetooth off, device shutdown, out of range)
Fix Required:
Add active connection check using SDK:

Gap #4: Webhook Timer Doesn't Send Disconnect Webhooks
Location: main.dart:832-880

Problem:

Timer checks _isConnected flag and should send disconnect webhook
BUT _isConnected flag is never updated (Gap #2), so disconnect webhook never triggers
Backend never receives disconnect notifications
Evidence from testing:

6:08:34, 6:10:34, 6:12:34 = No webhooks sent when device was shutdown
6:27:22, 6:29:22, 6:31:22 = No webhooks sent when device was out of range
Fix Required:
Depends on fixing Gap #2 first. Once _isConnected is properly updated, this will work automatically.

Gap #5: No Bluetooth State Listener
Location: Missing entirely

Problem:

App doesn't listen to Android Bluetooth on/off events
When user turns Bluetooth off, app doesn't know until data timeout (12 minutes currently)
Fix Required:
Add Bluetooth state listener in initState:

Gap #6: UI Doesn't Show Intermediate "Disconnected" State
Location: main.dart:2204-2217

Problem:

UI shows "Connected" or "Disconnected" based on _isConnected flag
When device disconnects but reconnection is in progress, UI jumps from "Connected" to "Reconnecting" without showing "Disconnected"
Users don't see the disconnect event clearly
Fix Required:
Add more granular status states:

Gap #7: Connection Monitor Stops When _isConnected is False
Location: main.dart:968-972

Problem:

Monitor checks if (!_isConnected) and cancels itself
Once _isConnected becomes false, monitor stops running
Monitor should keep running to detect when device comes back (for auto-reconnect)
Fix Required:

📊 SUMMARY OF ISSUES
Issue	Impact	Severity	Current Behavior	Expected Behavior
Monitoring timeout too long	12-min delay in disconnect detection	🔴 Critical	Waits 12 minutes	Should detect in 5 minutes
_isConnected not updated	UI shows wrong status	🔴 Critical	Shows "Connected" when disconnected	Should show "Disconnected"
No active connection check	Can't detect instant disconnects	🔴 Critical	Only checks data timestamps	Should actively ping device
No disconnect webhooks	Backend unaware of disconnects	🔴 Critical	No webhooks sent	Should send null-value webhooks
No Bluetooth state listener	Bluetooth off not detected	🟠 High	Waits for timeout	Should detect immediately
UI status not granular	Poor UX	🟡 Medium	Binary connected/disconnected	Should show reconnecting state
Monitor stops when disconnected	Can't facilitate auto-reconnect	🟡 Medium	Monitor stops	Should keep monitoring
🔧 PRIORITY FIX ORDER
Fix Gap #2 - Update _isConnected flag in stream error handler
Fix Gap #1 - Reduce monitoring timeout from 720s to 300s
Fix Gap #3 - Add active connection check
Fix Gap #5 - Add Bluetooth state listener
Fix Gap #7 - Keep monitor running when disconnected
Fix Gap #6 - Improve UI status display
Gap #4 will be automatically fixed once Gap #2 is resolved.

🎯 EXPECTED RESULTS AFTER FIXES
Device shutdown → UI shows "Disconnected" within 5 minutes (2-3 missed webhook cycles)
Device out of range → UI shows "Disconnected" within 5 minutes
Bluetooth off → UI shows "Disconnected" within 30 seconds (immediate detection)
Backend receives disconnect webhooks with null values at every 2-minute interval when disconnected
Reconnection attempts visible in UI with proper status messages