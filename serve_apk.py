#!/usr/bin/env python3
"""
Simple HTTP Server for APK Distribution
Serves the HFC App APK and download page
"""

import http.server
import socketserver
import os

# Configuration
PORT = 8080
DIRECTORY = "/workspaces/HFC-App"

class MyHTTPRequestHandler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=DIRECTORY, **kwargs)
    
    def end_headers(self):
        # Add CORS headers
        self.send_header('Access-Control-Allow-Origin', '*')
        super().end_headers()
    
    def do_GET(self):
        # Serve download page as index
        if self.path == '/':
            self.path = '/download-app.html'
        
        # Handle APK download
        if self.path == '/app-release.apk':
            # Try arm64 first (most common), then other architectures
            apk_candidates = [
                'build/app/outputs/flutter-apk/app-arm64-v8a-release.apk',
                'build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk',
                'build/app/outputs/flutter-apk/app-x86_64-release.apk',
                'build/app/outputs/flutter-apk/app-release.apk',
            ]
            
            apk_found = False
            for apk_file in apk_candidates:
                apk_path = os.path.join(DIRECTORY, apk_file)
                if os.path.exists(apk_path):
                    self.path = '/' + apk_file
                    apk_found = True
                    break
            
            if not apk_found:
                self.send_response(404)
                self.send_header('Content-type', 'text/html')
                self.end_headers()
                self.wfile.write(b'<html><body><h1>APK is still building...</h1><p>Please wait and refresh in a few moments.</p></body></html>')
                return
        
        return super().do_GET()

def run_server():
    with socketserver.TCPServer(("", PORT), MyHTTPRequestHandler) as httpd:
        print(f"""
╔══════════════════════════════════════════════════════════════════════╗
║                                                                      ║
║          🚀 HFC App Download Server Running!                        ║
║                                                                      ║
╚══════════════════════════════════════════════════════════════════════╝

📱 Server Details:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Port:              {PORT}
  Directory:         {DIRECTORY}
  Download Page:     http://localhost:{PORT}/
  Direct APK Link:   http://localhost:{PORT}/app-release.apk

🌐 Access from Mobile Device:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  1. Make sure your mobile is on the same network
  2. Find this computer's IP address
  3. Open browser on mobile: http://[YOUR-IP]:{PORT}/
  
📥 Download Instructions:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  1. Open the URL in your mobile browser
  2. Click "Download APK" button
  3. Enable "Install from Unknown Sources" in Android settings
  4. Install the APK
  5. Grant Bluetooth and Location permissions
  6. Connect your HC20 device
  7. Watch the cloud sync indicator! ☁️

✨ New Features in This Build:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  ☁️  Visual Cloud Sync Status Banner (Animated)
  📊  Real-time Data Upload Counter
  ✅  Success/Error Tracking
  ⏰  Last Sync Timestamp
  🔄  Live Health Metrics Updates

Press Ctrl+C to stop the server
        """)
        
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\n\n🛑 Server stopped.")

if __name__ == "__main__":
    run_server()
