#!/usr/bin/env python3
"""
HFC App APK Download Server
Serves both old and new APK versions with beautiful download pages
"""

import http.server
import socketserver
import os
from datetime import datetime

PORT = 8080

class CustomHTTPRequestHandler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        # Root path serves the new APK download page
        if self.path == '/':
            self.path = '/download-login.html'
        # Old APK download page
        elif self.path == '/old':
            self.path = '/download.html'
        
        return http.server.SimpleHTTPRequestHandler.do_GET(self)
    
    def end_headers(self):
        # Add CORS headers
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Cache-Control', 'no-store, no-cache, must-revalidate')
        super().end_headers()
    
    def log_message(self, format, *args):
        # Custom logging with emojis
        status_code = args[1] if len(args) > 1 else '000'
        if status_code.startswith('2'):
            emoji = '✅'
        elif status_code.startswith('3'):
            emoji = '🔄'
        elif status_code.startswith('4'):
            emoji = '❌'
        else:
            emoji = '⚠️'
        
        print(f"{emoji} {self.address_string()} - {format % args}")

def get_local_ip():
    import socket
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        ip = s.getsockname()[0]
        s.close()
        return ip
    except:
        return "127.0.0.1"

def main():
    os.chdir('/workspaces/HFC-App')
    
    with socketserver.TCPServer(("", PORT), CustomHTTPRequestHandler) as httpd:
        local_ip = get_local_ip()
        
        print("=" * 60)
        print("🚀 HFC APP APK DOWNLOAD SERVER")
        print("=" * 60)
        print("📡 Server started successfully!")
        print(f"🌐 Serving directory: {os.getcwd()}")
        print(f"🔢 Port: {PORT}")
        print()
        print("📱 Download Pages:")
        print(f"   NEW APK (with login):  http://localhost:{PORT}")
        print(f"                          http://{local_ip}:{PORT}")
        print()
        print(f"   OLD APK (no login):    http://localhost:{PORT}/old")
        print(f"                          http://{local_ip}:{PORT}/old")
        print()
        print("📥 Direct APK Downloads:")
        print(f"   NEW: http://localhost:{PORT}/app-release-with-login.apk (52.6 MB)")
        print(f"        http://{local_ip}:{PORT}/app-release-with-login.apk")
        print()
        print(f"   OLD: http://localhost:{PORT}/app-release.apk (47 MB)")
        print(f"        http://{local_ip}:{PORT}/app-release.apk")
        print()
        print("✨ NEW APK Features:")
        print("   • OTP Authentication (Phone: 9999999999, OTP: 123456)")
        print("   • User Profile Management")
        print("   • Device-User Association")
        print("   • Secure Token Storage")
        print("   • Terms & Conditions")
        print()
        print("🛑 Press Ctrl+C to stop the server")
        print("=" * 60)
        print()
        
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\n")
            print("🛑 Server stopped by user")
            print("✅ Goodbye!")

if __name__ == "__main__":
    main()
