#!/usr/bin/env python3
"""
Simple vault file server that runs on the host
Serves files directly from the mounted vault directory
"""

import os
import json
import http.server
import socketserver
from urllib.parse import urlparse, unquote
import mimetypes

class VaultFileHandler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        self.vault_path = "/Users/aq_home/Journals"
        super().__init__(*args, **kwargs)
    
    def do_GET(self):
        parsed_path = urlparse(self.path)
        path = unquote(parsed_path.path)
        
        # Handle API endpoints
        if path.startswith('/api/'):
            self.handle_api(path)
            return
            
        # Serve files from vault
        if path == '/' or path == '/index.html':
            self.serve_file_browser()
        else:
            self.serve_file(path)
    
    def handle_api(self, path):
        if path == '/api/files':
            self.list_files()
        elif path.startswith('/api/file/'):
            file_path = path[10:]  # Remove '/api/file/'
            self.get_file_info(file_path)
        else:
            self.send_error(404, "API endpoint not found")
    
    def list_files(self):
        """List all files in the vault directory"""
        try:
            files = []
            for root, dirs, filenames in os.walk(self.vault_path):
                for filename in filenames:
                    if filename.endswith(('.md', '.txt', '.markdown')):
                        full_path = os.path.join(root, filename)
                        rel_path = os.path.relpath(full_path, self.vault_path)
                        stat = os.stat(full_path)
                        files.append({
                            'name': filename,
                            'path': rel_path,
                            'size': stat.st_size,
                            'modified': stat.st_mtime,
                            'type': 'file'
                        })
            
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.send_header('Access-Control-Allow-Origin', '*')
            self.end_headers()
            self.wfile.write(json.dumps(files).encode())
        except Exception as e:
            self.send_error(500, f"Error listing files: {str(e)}")
    
    def get_file_info(self, file_path):
        """Get information about a specific file"""
        try:
            full_path = os.path.join(self.vault_path, file_path)
            if not os.path.exists(full_path):
                self.send_error(404, "File not found")
                return
                
            stat = os.stat(full_path)
            info = {
                'name': os.path.basename(file_path),
                'path': file_path,
                'size': stat.st_size,
                'modified': stat.st_mtime,
                'type': 'file'
            }
            
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.send_header('Access-Control-Allow-Origin', '*')
            self.end_headers()
            self.wfile.write(json.dumps(info).encode())
        except Exception as e:
            self.send_error(500, f"Error getting file info: {str(e)}")
    
    def serve_file(self, path):
        """Serve a file from the vault"""
        try:
            # Remove leading slash
            if path.startswith('/'):
                path = path[1:]
            
            full_path = os.path.join(self.vault_path, path)
            
            if not os.path.exists(full_path):
                self.send_error(404, "File not found")
                return
            
            if not os.path.isfile(full_path):
                self.send_error(400, "Not a file")
                return
            
            # Get MIME type
            mime_type, _ = mimetypes.guess_type(full_path)
            if mime_type is None:
                mime_type = 'text/plain'
            
            # Read and serve file
            with open(full_path, 'rb') as f:
                content = f.read()
            
            self.send_response(200)
            self.send_header('Content-type', mime_type)
            self.send_header('Content-length', str(len(content)))
            self.send_header('Access-Control-Allow-Origin', '*')
            self.end_headers()
            self.wfile.write(content)
            
        except Exception as e:
            self.send_error(500, f"Error serving file: {str(e)}")
    
    def serve_file_browser(self):
        """Serve the file browser HTML interface"""
        html = """
<!DOCTYPE html>
<html>
<head>
    <title>Journal Vault Browser</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background: #f5f5f5; }
        .container { max-width: 800px; margin: 0 auto; background: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        .file-list { list-style: none; padding: 0; }
        .file-item { 
            padding: 15px; 
            border: 1px solid #ddd; 
            margin: 10px 0; 
            border-radius: 8px;
            background: #f9f9f9;
            transition: all 0.2s;
        }
        .file-item:hover { 
            background: #e9e9e9; 
            transform: translateY(-2px);
            box-shadow: 0 4px 8px rgba(0,0,0,0.1);
        }
        .file-name { font-weight: bold; color: #333; font-size: 16px; margin-bottom: 5px; }
        .file-path { color: #666; font-size: 14px; margin-bottom: 5px; }
        .file-size { color: #888; font-size: 12px; }
        .file-link { text-decoration: none; color: inherit; display: block; }
        .refresh-btn { 
            background: #007bff; 
            color: white; 
            border: none; 
            padding: 12px 24px; 
            border-radius: 6px; 
            cursor: pointer;
            margin-bottom: 20px;
            font-size: 14px;
        }
        .refresh-btn:hover { background: #0056b3; }
        .header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 20px; }
        .loading { text-align: center; padding: 20px; color: #666; }
        .error { color: #dc3545; background: #f8d7da; padding: 10px; border-radius: 4px; margin: 10px 0; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>📁 Journal Vault Browser</h1>
            <button class="refresh-btn" onclick="loadFiles()">🔄 Refresh Files</button>
        </div>
        <div id="loading" class="loading">Loading vault files...</div>
        <ul id="file-list" class="file-list"></ul>
    </div>
    
    <script>
        function loadFiles() {
            document.getElementById('loading').style.display = 'block';
            document.getElementById('file-list').innerHTML = '';
            
            fetch('/api/files')
                .then(response => response.json())
                .then(files => {
                    document.getElementById('loading').style.display = 'none';
                    const fileList = document.getElementById('file-list');
                    
                    if (files.length === 0) {
                        fileList.innerHTML = '<li class="file-item"><div class="file-name">No files found</div><div class="file-path">No markdown files found in the vault</div></li>';
                        return;
                    }
                    
                    files.forEach(file => {
                        const li = document.createElement('li');
                        li.className = 'file-item';
                        li.innerHTML = `
                            <a href="/${file.path}" class="file-link" target="_blank">
                                <div class="file-name">📄 ${file.name}</div>
                                <div class="file-path">${file.path}</div>
                                <div class="file-size">${formatFileSize(file.size)} - ${new Date(file.modified * 1000).toLocaleString()}</div>
                            </a>
                        `;
                        fileList.appendChild(li);
                    });
                })
                .catch(error => {
                    document.getElementById('loading').innerHTML = `<div class="error">Error loading files: ${error.message}</div>`;
                });
        }
        
        function formatFileSize(bytes) {
            if (bytes === 0) return '0 Bytes';
            const k = 1024;
            const sizes = ['Bytes', 'KB', 'MB', 'GB'];
            const i = Math.floor(Math.log(bytes) / Math.log(k));
            return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
        }
        
        // Load files on page load
        loadFiles();
    </script>
</body>
</html>
        """
        
        self.send_response(200)
        self.send_header('Content-type', 'text/html')
        self.send_header('Access-Control-Allow-Origin', '*')
        self.end_headers()
        self.wfile.write(html.encode())

if __name__ == '__main__':
    port = 8082
    with socketserver.TCPServer(("", port), VaultFileHandler) as httpd:
        print(f"Vault file server running on http://localhost:{port}")
        print(f"Serving files from: /Users/aq_home/Journals")
        print("Press Ctrl+C to stop")
        httpd.serve_forever()
