#!/usr/bin/env python3
"""
Simple file server for vault documents
Serves files from the mounted vault directory
"""

import os
import json
from http.server import HTTPServer, SimpleHTTPRequestHandler
from urllib.parse import urlparse, unquote
import mimetypes

class VaultFileHandler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        self.vault_path = "/journals"
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
        body { font-family: Arial, sans-serif; margin: 20px; }
        .file-list { list-style: none; padding: 0; }
        .file-item { 
            padding: 10px; 
            border: 1px solid #ddd; 
            margin: 5px 0; 
            border-radius: 5px;
            background: #f9f9f9;
        }
        .file-item:hover { background: #e9e9e9; }
        .file-name { font-weight: bold; color: #333; }
        .file-path { color: #666; font-size: 0.9em; }
        .file-size { color: #888; font-size: 0.8em; }
        .file-link { text-decoration: none; color: inherit; }
        .refresh-btn { 
            background: #007bff; 
            color: white; 
            border: none; 
            padding: 10px 20px; 
            border-radius: 5px; 
            cursor: pointer;
            margin-bottom: 20px;
        }
        .refresh-btn:hover { background: #0056b3; }
    </style>
</head>
<body>
    <h1>Journal Vault Browser</h1>
    <button class="refresh-btn" onclick="loadFiles()">Refresh Files</button>
    <div id="loading">Loading files...</div>
    <ul id="file-list" class="file-list"></ul>
    
    <script>
        function loadFiles() {
            document.getElementById('loading').style.display = 'block';
            document.getElementById('file-list').innerHTML = '';
            
            fetch('/api/files')
                .then(response => response.json())
                .then(files => {
                    document.getElementById('loading').style.display = 'none';
                    const fileList = document.getElementById('file-list');
                    
                    files.forEach(file => {
                        const li = document.createElement('li');
                        li.className = 'file-item';
                        li.innerHTML = `
                            <a href="/${file.path}" class="file-link" target="_blank">
                                <div class="file-name">${file.name}</div>
                                <div class="file-path">${file.path}</div>
                                <div class="file-size">${formatFileSize(file.size)} - ${new Date(file.modified * 1000).toLocaleString()}</div>
                            </a>
                        `;
                        fileList.appendChild(li);
                    });
                })
                .catch(error => {
                    document.getElementById('loading').innerHTML = 'Error loading files: ' + error.message;
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
    port = int(os.environ.get('PORT', 8081))
    server = HTTPServer(('0.0.0.0', port), VaultFileHandler)
    print(f"Vault file server running on port {port}")
    server.serve_forever()

