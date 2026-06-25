# Component Diagram

This document contains a simplified Mermaid diagram showing the component architecture and service locations of the Local Journal system.

## Component Overview

The Local Journal system consists of core components, containerized services, and storage systems that work together to provide secure AI-assisted journaling capabilities.

## Component Diagram

```mermaid
graph TB
    %% User Interface
    subgraph "User Interface"
        User[👤 User]
        CLI[📱 CLI Scripts<br/>bin/]
        WebUI[🌐 Web Interface<br/>localhost:3000]
    end

    %% Host System Components
    subgraph "Host System (macOS)"
        subgraph "Management Scripts"
            VaultManager[🔐 Vault Manager<br/>src/vault/]
            DockerManager[🐳 Docker Manager<br/>src/docker/]
            ModelManager[🤖 Model Manager<br/>src/model/]
        end
        
        subgraph "Docker Containers"
            Ollama[🧠 Ollama<br/>localhost:11434<br/>AI Model Server]
            OpenWebUI[🌐 Open WebUI<br/>localhost:3000<br/>AI Interface]
            VaultServer[📁 Vault Server<br/>localhost:8081<br/>File API]
        end
        
        subgraph "Storage Systems"
            APFSVault[🔐 APFS Vault<br/>~/JournalsVault.sparseimage<br/>AES-256 Encrypted]
            VaultMount[📂 Vault Mount<br/>~/Journals<br/>Decrypted Files]
            DockerVolumes[💾 Docker Volumes<br/>ollama-data, webui-data, journals-data]
        end
    end

    %% External Dependencies
    subgraph "External Dependencies"
        Docker[🐳 Docker Desktop]
        APFS[💽 APFS File System]
        Internet[🌍 Internet<br/>Model Downloads]
    end

    %% User Connections
    User --> CLI
    User --> WebUI

    %% CLI to Management Scripts
    CLI --> VaultManager
    CLI --> DockerManager
    CLI --> ModelManager

    %% WebUI to Container
    WebUI --> OpenWebUI

    %% Management Script Dependencies
    VaultManager --> APFSVault
    VaultManager --> VaultMount
    DockerManager --> Ollama
    DockerManager --> OpenWebUI
    DockerManager --> VaultServer
    ModelManager --> Ollama

    %% Container Dependencies
    OpenWebUI --> Ollama
    VaultServer --> Ollama
    OpenWebUI --> VaultServer

    %% Storage Connections
    VaultServer --> VaultMount
    OpenWebUI --> DockerVolumes
    Ollama --> DockerVolumes
    VaultServer --> DockerVolumes

    %% External Dependencies
    DockerManager --> Docker
    VaultManager --> APFS
    ModelManager --> Internet

    %% Styling
    classDef userInterface fill:#e1f5fe,stroke:#01579b,stroke-width:2px
    classDef management fill:#e8f5e8,stroke:#1b5e20,stroke-width:2px
    classDef containers fill:#fff3e0,stroke:#e65100,stroke-width:2px
    classDef storage fill:#fce4ec,stroke:#880e4f,stroke-width:2px
    classDef external fill:#f5f5f5,stroke:#424242,stroke-width:2px

    class User,CLI,WebUI userInterface
    class VaultManager,DockerManager,ModelManager management
    class Ollama,OpenWebUI,VaultServer containers
    class APFSVault,VaultMount,DockerVolumes storage
    class Docker,APFS,Internet external
```

## Service Locations

### **Container Services (Docker)**
- **Ollama AI Server**: `localhost:11434` - Serves AI models locally
- **Open WebUI**: `localhost:3000` - Web interface for AI interaction  
- **Vault File Server**: `localhost:8081` - API for journal file access

### **Host Services (Bash Scripts)**
- **Vault Manager**: `src/vault/` - APFS vault operations (create, mount, unmount)
- **Docker Manager**: `src/docker/` - Container lifecycle management
- **Model Manager**: `src/model/` - Ollama model management and optimization

### **Storage Components**
- **APFS Sparse Image**: `~/JournalsVault.sparseimage` - Encrypted vault
- **Vault Mount Point**: `~/Journals` - Decrypted journal files
- **Docker Volumes**: Persistent container data storage

## Component Relationships

### **User Access**
- Users interact through CLI scripts or web interface
- CLI provides system management capabilities
- WebUI provides AI-assisted journaling interface

### **Service Dependencies**
- **Open WebUI** depends on **Ollama** for AI processing
- **Vault Server** provides file access to **Open WebUI**
- **Docker Manager** orchestrates all container services
- **Vault Manager** handles encrypted storage operations
- **Model Manager** manages AI model lifecycle

### **Storage Architecture**
- **APFS Vault** provides encrypted storage at rest
- **Vault Mount** provides decrypted file access
- **Docker Volumes** provide persistent container data
- **Vault Server** bridges container access to vault files

## Security Boundaries

- **Network**: All services bound to localhost only (127.0.0.1)
- **File System**: Journal files mounted read-only to AI containers
- **Encryption**: AES-256 encryption for all persistent storage
- **Isolation**: Docker containers with minimal privileges

This component diagram shows the essential architecture and service locations without the detailed operational processes, focusing on where components are located and how they connect.
