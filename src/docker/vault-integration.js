// Vault Integration for Open WebUI
// This script adds vault file access to the WebUI interface

(function() {
    'use strict';
    
    // Configuration
    const VAULT_SERVER_URL = 'http://127.0.0.1:8081';
    const VAULT_BROWSER_URL = `${VAULT_SERVER_URL}/`;
    
    // Add vault access button to the UI
    function addVaultButton() {
        // Wait for the UI to load
        const checkForUI = setInterval(() => {
            const chatContainer = document.querySelector('.chat-container') || 
                                document.querySelector('[class*="chat"]') ||
                                document.querySelector('main');
            
            if (chatContainer) {
                clearInterval(checkForUI);
                createVaultInterface();
            }
        }, 1000);
    }
    
    function createVaultInterface() {
        // Create vault access panel
        const vaultPanel = document.createElement('div');
        vaultPanel.id = 'vault-panel';
        vaultPanel.style.cssText = `
            position: fixed;
            top: 20px;
            right: 20px;
            width: 300px;
            max-height: 500px;
            background: white;
            border: 1px solid #ddd;
            border-radius: 8px;
            box-shadow: 0 4px 12px rgba(0,0,0,0.1);
            z-index: 1000;
            display: none;
            overflow: hidden;
        `;
        
        vaultPanel.innerHTML = `
            <div style="padding: 15px; border-bottom: 1px solid #eee; background: #f8f9fa;">
                <div style="display: flex; justify-content: space-between; align-items: center;">
                    <h3 style="margin: 0; font-size: 16px;">Journal Vault</h3>
                    <button id="close-vault" style="background: none; border: none; font-size: 18px; cursor: pointer;">×</button>
                </div>
            </div>
            <div id="vault-content" style="padding: 15px; max-height: 400px; overflow-y: auto;">
                <div id="vault-loading">Loading vault files...</div>
            </div>
        `;
        
        document.body.appendChild(vaultPanel);
        
        // Add vault button to the main interface
        const vaultButton = document.createElement('button');
        vaultButton.innerHTML = '📁 Vault Files';
        vaultButton.style.cssText = `
            position: fixed;
            top: 20px;
            right: 20px;
            background: #007bff;
            color: white;
            border: none;
            padding: 10px 15px;
            border-radius: 5px;
            cursor: pointer;
            z-index: 999;
            font-size: 14px;
        `;
        
        vaultButton.onclick = () => {
            vaultPanel.style.display = vaultPanel.style.display === 'none' ? 'block' : 'none';
            if (vaultPanel.style.display === 'block') {
                loadVaultFiles();
            }
        };
        
        document.body.appendChild(vaultButton);
        
        // Close button functionality
        document.getElementById('close-vault').onclick = () => {
            vaultPanel.style.display = 'none';
        };
        
        // Load vault files
        loadVaultFiles();
    }
    
    function loadVaultFiles() {
        const content = document.getElementById('vault-content');
        content.innerHTML = '<div id="vault-loading">Loading vault files...</div>';
        
        fetch(`${VAULT_SERVER_URL}/api/files`)
            .then(response => response.json())
            .then(files => {
                if (files.length === 0) {
                    content.innerHTML = '<p>No files found in vault.</p>';
                    return;
                }
                
                const fileList = files.map(file => `
                    <div style="padding: 8px; border-bottom: 1px solid #eee; cursor: pointer;" 
                         onclick="openVaultFile('${file.path}')">
                        <div style="font-weight: bold; color: #333;">${file.name}</div>
                        <div style="font-size: 12px; color: #666;">${file.path}</div>
                        <div style="font-size: 11px; color: #888;">${formatFileSize(file.size)}</div>
                    </div>
                `).join('');
                
                content.innerHTML = `
                    <div style="margin-bottom: 10px;">
                        <button onclick="refreshVaultFiles()" style="background: #28a745; color: white; border: none; padding: 5px 10px; border-radius: 3px; cursor: pointer; font-size: 12px;">Refresh</button>
                        <button onclick="openVaultBrowser()" style="background: #17a2b8; color: white; border: none; padding: 5px 10px; border-radius: 3px; cursor: pointer; font-size: 12px; margin-left: 5px;">Full Browser</button>
                    </div>
                    ${fileList}
                `;
            })
            .catch(error => {
                content.innerHTML = `<p style="color: red;">Error loading vault files: ${error.message}</p>`;
            });
    }
    
    function openVaultFile(filePath) {
        const url = `${VAULT_SERVER_URL}/${filePath}`;
        window.open(url, '_blank');
    }
    
    function openVaultBrowser() {
        window.open(VAULT_BROWSER_URL, '_blank');
    }
    
    function refreshVaultFiles() {
        loadVaultFiles();
    }
    
    function formatFileSize(bytes) {
        if (bytes === 0) return '0 Bytes';
        const k = 1024;
        const sizes = ['Bytes', 'KB', 'MB', 'GB'];
        const i = Math.floor(Math.log(bytes) / Math.log(k));
        return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
    }
    
    // Make functions globally available
    window.openVaultFile = openVaultFile;
    window.openVaultBrowser = openVaultBrowser;
    window.refreshVaultFiles = refreshVaultFiles;
    
    // Initialize when DOM is ready
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', addVaultButton);
    } else {
        addVaultButton();
    }
    
})();

