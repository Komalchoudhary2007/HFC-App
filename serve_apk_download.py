#!/usr/bin/env python3
"""
HFC App APK Download Server
Serves the APK file and download page on port 8080
"""

import http.server
import socketserver
import os
import sys
from pathlib import Path

# Configuration
PORT = 8080
DIRECTORY = "/workspaces/HFC-App"

class CustomHTTPRequestHandler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=DIRECTORY, **kwargs)
    
    def end_headers(self):
        # Add CORS headers for cross-origin requests
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', '*')
        super().end_headers()
    
    def do_GET(self):
        # Serve the download page at root
        if self.path == '/':
            self.path = '/download-new.html'
        
        # Serve APK with correct MIME type
        if self.path.endswith('.apk'):
            apk_path = DIRECTORY + '/build/app/outputs/flutter-apk/app-release.apk'
            if os.path.exists(apk_path):
                self.send_response(200)
                self.send_header('Content-Type', 'application/vnd.android.package-archive')
                self.send_header('Content-Disposition', 'attachment; filename="HFC-App-v1.10.1.apk"')
                self.send_header('Content-Length', str(os.path.getsize(apk_path)))
                self.end_headers()
                
                with open(apk_path, 'rb') as f:
                    self.wfile.write(f.read())
                return
        
        # Default handling for other files
        super().do_GET()
    
    def log_message(self, format, *args):
        # Custom logging with emojis
        if '200' in str(args):
            emoji = '✅'
        elif '404' in str(args):
            emoji = '❌'
        else:
            emoji = '📡'
        
        sys.stdout.write(f"{emoji} {self.address_string()} - {format % args}\n")
        sys.stdout.flush()

def get_local_ip():
    """Get the local IP address"""
    import socket
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        local_ip = s.getsockname()[0]
        s.close()
        return local_ip
    except:
        return "localhost"

def main():
    # Change to the app directory
    os.chdir(DIRECTORY)
    
    # Create server
    Handler = CustomHTTPRequestHandler
    
    with socketserver.TCPServer(("", PORT), Handler) as httpd:
        local_ip = get_local_ip()
        
        print("\n" + "="*60)
        print("🚀 HFC APP APK DOWNLOAD SERVER")
        print("="*60)
        print(f"📡 Server started successfully!")
        print(f"🌐 Serving directory: {DIRECTORY}")
        print(f"🔢 Port: {PORT}")
        print("\n📱 Access the download page:")
        print(f"   Local:    http://localhost:{PORT}")
        print(f"   Network:  http://{local_ip}:{PORT}")
        print("\n⚠️  IMPORTANT:")
        print("   This APK does NOT include the new login system!")
        print("   Build date: Dec 30, 2025 (before login implementation)")
        print("\n📥 Direct APK download:")
        print(f"   http://localhost:{PORT}/app-release.apk")
        print(f"   http://{local_ip}:{PORT}/app-release.apk")
        print("\n🛑 Press Ctrl+C to stop the server")
        print("="*60 + "\n")
        
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\n\n🛑 Server stopped by user")
            print("✅ Goodbye!\n")
            sys.exit(0)

if __name__ == "__main__":
    main()
