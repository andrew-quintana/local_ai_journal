# Date Handling Rules

## Rule: Always Use CLI to Get Current Date

**NEVER hardcode dates in scripts, documentation, or any files.**

### ❌ Wrong Approach
```bash
# Date: 2025-01-18
echo "Version: 2.0"
echo "Date: 2025-01-18"
```

### ✅ Correct Approach
```bash
# Get current date from CLI
CURRENT_DATE=$(date '+%Y-%m-%d')
CURRENT_TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# Use in scripts
echo "Date: $CURRENT_DATE"
echo "Last Updated: $CURRENT_TIMESTAMP"
```

## Implementation Guidelines

### 1. Script Headers
```bash
#!/usr/bin/env bash
# script-name.sh - Description
# 
# Author: Local Development Team
# Version: 2.0
# Date: $(date '+%Y-%m-%d')
```

### 2. Version Information Functions
```bash
show_version() {
    echo "Script Name"
    echo "Version: 2.0"
    echo "Date: $(date '+%Y-%m-%d')"
    echo "Author: Local Development Team"
}
```

### 3. Documentation Headers
```markdown
**Document Version**: 2.0  
**Last Updated**: $(date '+%Y-%m-%d')  
**Author**: Local Development Team
```

### 4. Log Messages
```bash
log() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $*"
}
```

## Common Date Formats

| Format | Command | Example Output |
|--------|---------|----------------|
| ISO Date | `date '+%Y-%m-%d'` | 2025-09-18 |
| Timestamp | `date '+%Y-%m-%d %H:%M:%S'` | 2025-09-18 16:12:12 |
| Short Date | `date '+%m/%d/%Y'` | 09/18/2025 |
| Long Date | `date '+%B %d, %Y'` | September 18, 2025 |
| Year Only | `date '+%Y'` | 2025 |
| Month Only | `date '+%m'` | 09 |
| Day Only | `date '+%d'` | 18 |

## Automated Date Updates

### Script Template
```bash
#!/usr/bin/env bash
# Update all hardcoded dates in project

# Get current date
CURRENT_DATE=$(date '+%Y-%m-%d')

# Find and replace hardcoded dates
find . -type f -name "*.sh" -exec sed -i "s/2025-01-18/$CURRENT_DATE/g" {} \;
find . -type f -name "*.md" -exec sed -i "s/2025-01-18/$CURRENT_DATE/g" {} \;
```

### Git Hooks
```bash
#!/bin/bash
# pre-commit hook to check for hardcoded dates

# Check for hardcoded dates
if grep -r "2025-01-18\|2025-01-19\|2025-01-20" . --exclude-dir=.git; then
    echo "❌ Hardcoded dates found! Use CLI to get current date."
    exit 1
fi
```

## Benefits

1. **Accuracy**: Always reflects current date
2. **Maintenance**: No need to manually update dates
3. **Consistency**: All dates use same format
4. **Automation**: Can be automated in CI/CD
5. **Version Control**: Dates in git history are accurate

## Tools

### Date Utility Script
Use `./scripts/get-current-date.sh` to get current date in various formats:

```bash
./scripts/get-current-date.sh iso      # 2025-09-18
./scripts/get-current-date.sh short    # 09/18/2025
./scripts/get-current-date.sh long     # September 18, 2025
./scripts/get-current-date.sh timestamp # 2025-09-18 16:12:12
```

### Validation Script
```bash
#!/bin/bash
# validate-dates.sh - Check for hardcoded dates

echo "Checking for hardcoded dates..."
if grep -r "2025-01-18" . --exclude-dir=.git --exclude="DATE_HANDLING_RULES.md"; then
    echo "❌ Found hardcoded dates!"
    exit 1
else
    echo "✅ No hardcoded dates found"
fi
```

## Enforcement

1. **Code Review**: Always check for hardcoded dates
2. **Automated Checks**: Use scripts to validate
3. **Documentation**: Update this rule when needed
4. **Training**: Team members must follow this rule

---

**Rule Created**: 2025-09-18  
**Last Updated**: $(date '+%Y-%m-%d')  
**Enforcement**: Mandatory for all project files
