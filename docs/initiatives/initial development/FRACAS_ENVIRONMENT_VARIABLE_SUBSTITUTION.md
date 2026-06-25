# FRACAS: Environment Variable Substitution Failure

**FRACAS ID**: FRACAS-004  
**Date**: 2025-01-18  
**Priority**: MEDIUM  
**Status**: RESOLVED  
**Component**: Docker Configuration  

## 🚨 **Failure Summary**

Environment variable substitution using `$(openssl rand -base64 32)` failed in Docker Compose, causing WebUI to fail startup due to missing secret keys.

## 📋 **Failure Description**

### **Primary Failure**
- **Issue**: `$(openssl rand -base64 32)` substitution not working in Docker Compose
- **Impact**: WebUI failed to start due to missing `WEBUI_SECRET_KEY` and `WEBUI_JWT_SECRET_KEY`
- **Severity**: MEDIUM - Configuration issue preventing startup

### **Symptoms Observed**
1. **WebUI Logs**: Missing or invalid secret key errors
2. **Container Status**: WebUI container failing to start properly
3. **Environment**: Variables not being substituted correctly
4. **Configuration**: Docker Compose environment section appeared correct

## ✅ **Resolution Details**

### **Root Cause Identified**
- **Issue**: Docker Compose does not support shell command substitution in environment variables
- **Location**: `src/docker/docker-compose.yml` lines 104-105
- **Impact**: Secret keys not generated, causing WebUI startup failure

### **Solution Implemented**
- **Change**: Replaced `$(openssl rand -base64 32)` with pre-generated static values
- **Result**: WebUI now starts successfully with valid secret keys
- **Validation**: WebUI accessible and functional

### **Configuration Change**
```yaml
# Before (failing)
- WEBUI_SECRET_KEY=${WEBUI_SECRET_KEY:-$(openssl rand -base64 32)}
- WEBUI_JWT_SECRET_KEY=${WEBUI_JWT_SECRET_KEY:-$(openssl rand -base64 32)}

# After (working)
- WEBUI_SECRET_KEY=${WEBUI_SECRET_KEY:-TQ8wmRWLlIVhelwyM1tdHJkN1cpbrFNqxBsUn7kbJM0=}
- WEBUI_JWT_SECRET_KEY=${WEBUI_JWT_SECRET_KEY:-kzIdNaWu8WsNF4oXP54QNC+k0JF4EGVu+bT2UzpkNsw=}
```

## 🔄 **Status Updates**

| Date | Status | Update |
|------|--------|--------|
| 2025-01-18 | OPEN | Issue identified during WebUI testing |
| 2025-01-18 | RESOLVED | Static values implemented |

---

**Created**: 2025-01-18  
**Last Updated**: 2025-01-18  
**Resolution**: Static secret key values
