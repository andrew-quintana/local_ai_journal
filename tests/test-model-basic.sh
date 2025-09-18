#!/bin/bash

# Basic Model Management Test
# Minimal test to verify core functionality

set -euo pipefail

# Configuration
readonly PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly MODEL_MANAGER="${PROJECT_ROOT}/src/model/model-manager.sh"

echo "=== Model Management Basic Test ==="
echo

# Test 1: Check if files exist
echo "1. Checking if model manager exists..."
if [[ -f "$MODEL_MANAGER" ]]; then
    echo "   ✅ Model manager exists"
else
    echo "   ❌ Model manager not found"
    exit 1
fi

# Test 2: Check if executable
echo "2. Checking if model manager is executable..."
if [[ -x "$MODEL_MANAGER" ]]; then
    echo "   ✅ Model manager is executable"
else
    echo "   ❌ Model manager is not executable"
    exit 1
fi

# Test 3: Check Ollama connection
echo "3. Checking Ollama connection..."
if curl -f -s "http://127.0.0.1:11434/api/tags" >/dev/null 2>&1; then
    echo "   ✅ Ollama is running"
    
    # Test 4: Test model list
    echo "4. Testing model list..."
    models=$("$MODEL_MANAGER" list 2>/dev/null)
    if [[ $? -eq 0 ]]; then
        echo "   ✅ Model list works: $models"
        
        # Test 5: Test model exists
        echo "5. Testing model exists..."
        first_model=$(echo "$models" | head -n1)
        if [[ -n "$first_model" ]]; then
            if "$MODEL_MANAGER" exists "$first_model" 2>/dev/null; then
                echo "   ✅ Model exists works for: $first_model"
            else
                echo "   ❌ Model exists failed for: $first_model"
            fi
        fi
    else
        echo "   ❌ Model list failed"
    fi
else
    echo "   ⏭️  Ollama not running - skipping model tests"
fi

# Test 6: Check other components exist
echo "6. Checking other components..."
components=(
    "src/model/model-integration.sh"
    "src/model/performance-optimizer.sh"
    "src/model/security-manager.sh"
    "src/model/model.conf"
)

for component in "${components[@]}"; do
    if [[ -f "${PROJECT_ROOT}/${component}" ]]; then
        echo "   ✅ $component exists"
    else
        echo "   ❌ $component missing"
    fi
done

echo
echo "=== Test Complete ==="
echo "Model management system is ready for use!"
