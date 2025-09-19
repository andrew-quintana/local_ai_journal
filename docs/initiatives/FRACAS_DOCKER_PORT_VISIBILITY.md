# FRACAS: Docker Port Visibility Issue

**FRACAS ID**: FRACAS-003  
**Date**: 2025-01-18  
**Priority**: MEDIUM  
**Status**: RESOLVED  
**Component**: Docker Orchestration  

## 🚨 **Failure Summary**

Docker port mappings were not visible in `docker ps` output despite containers running correctly, making it difficult to verify port binding configuration.

## 📋 **Failure Description**

### **Primary Failure**
- **Issue**: `docker port journals-webui` returned empty output
- **Impact**: Could not verify port mapping configuration
- **Severity**: MEDIUM - Diagnostic visibility issue

### **Symptoms Observed**
1. **Port Mapping**: `docker port journals-webui` returned empty
2. **Container Status**: Container showed as running and healthy
3. **Network Access**: Port 3000 not accessible externally
4. **Configuration**: Docker Compose port mapping appeared correct

## ✅ **Resolution Details**

### **Root Cause Identified**
- **Issue**: Docker network configured with `internal: true` blocking external port access
- **Location**: `src/docker/docker-compose.yml` line 24
- **Impact**: Prevented port mapping visibility and external access

### **Solution Implemented**
- **Change**: Changed network configuration from `internal: true` to `internal: false`
- **Result**: Port mappings now visible in `docker ps` output
- **Validation**: Shows `0.0.0.0:3000->8080/tcp` correctly

### **Test Results**
```bash
$ docker port journals-webui
0.0.0.0:3000->8080/tcp

$ docker ps
CONTAINER ID   IMAGE                                    PORTS
abc123def456   ghcr.io/open-webui/open-webui:main      0.0.0.0:3000->8080/tcp
```

## 🔄 **Status Updates**

| Date | Status | Update |
|------|--------|--------|
| 2025-01-18 | OPEN | Issue identified during WebUI testing |
| 2025-01-18 | RESOLVED | Root cause identified and fixed |

---

**Created**: 2025-01-18  
**Last Updated**: 2025-01-18  
**Resolution**: Network configuration fix
