# Database Foundation Implementation Prompt

**Phase**: Database Foundation  
**Component**: Local Supabase with pgvector for RAG Storage  
**Reference**: PRD001.md, RFC001.md  

## 🎯 **Objective**
Establish local Supabase database with pgvector extension for secure vector storage within encrypted vault boundary.

## 🔧 **Functions to Implement**

```python
# database_manager.py - Core database operations
class DatabaseManager:
    def initialize_database() -> bool
    def create_schema() -> bool
    def health_check() -> DatabaseStatus
    def backup_database() -> bool
    def validate_vault_storage() -> bool
```

## 🛡️ **Security Implementation Guidelines**

### Data Protection
- Database files stored within encrypted vault only
- No external network access for database operations
- Localhost-only binding (127.0.0.1:5432)
- Secure credential management without logging

### Vault Integration
- Database initialization as part of vault mount
- Database shutdown before vault unmount
- Backup inclusion in vault backup procedures
- Error handling for vault state changes

## 📚 **Reference Documents**
- **PRD001.md**: Privacy requirements and storage constraints
- **RFC001.md**: Database schema and technical specifications

## 🧪 **Testing Requirements**
1. Verify database creates within vault boundary
2. Test pgvector extension functionality
3. Validate localhost-only connectivity
4. Test integration with vault lifecycle

---

**Document Version**: 1.0  
**Created**: 2025-01-18  
**Phase**: Database Foundation  
**Priority**: Critical