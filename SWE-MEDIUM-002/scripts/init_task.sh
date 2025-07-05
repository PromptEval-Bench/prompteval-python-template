#!/bin/bash
# PVLib Golden Section Search Fix Initialization Script

set -e  # Exit on error

echo "🚀 Initializing PVLib Golden Section Search Fix Challenge..."

# Basic setup
sudo apt-get update > /dev/null 2>&1
sudo apt-get install -y bc jq curl > /dev/null 2>&1

# Load configuration
CONFIG_DIR="config"
TEMPLATE_DIR="template"

# Generate random parameters
HANDLER_OPTIONS=("StreamHandler" "FileHandler" "ConsoleHandler")
LOG_LEVEL_OPTIONS=("DEBUG" "INFO" "WARNING" "ERROR")
TOLERANCE_OPTIONS=("1e-15" "1e-14" "1e-13" "1e-12")

HANDLER_TYPE=${HANDLER_OPTIONS[$RANDOM % ${#HANDLER_OPTIONS[@]}]}
LOG_LEVEL=${LOG_LEVEL_OPTIONS[$RANDOM % ${#LOG_LEVEL_OPTIONS[@]}]}
MODULE_COMPLEXITY=$((RANDOM % 6 + 3))  # 3-8
TOLERANCE_PRECISION=${TOLERANCE_OPTIONS[$RANDOM % ${#TOLERANCE_OPTIONS[@]}]}
ERROR_THRESHOLD=$(echo "scale=2; ($RANDOM % 5 + 1) / 100000000000000000" | bc)

echo "📊 Generated parameters:"
echo "   - Handler type: $HANDLER_TYPE"  
echo "   - Log level: $LOG_LEVEL"
echo "   - Module complexity: $MODULE_COMPLEXITY"
echo "   - Tolerance: $TOLERANCE_PRECISION"

# Generate current date
CURRENT_DATE=$(date +%Y-%m-%d)

# Call LLM for dynamic content (with fallbacks)
if [ ! -z "$LLM_API_URL" ] && [ ! -z "$LLM_API_KEY" ]; then
    echo "🤖 Generating dynamic content with LLM..."
    
    # Generate library name
    LIBRARY_NAME=$(curl -s -X POST "$LLM_API_URL/v1/completions" \
        -H "Authorization: Bearer $LLM_API_KEY" \
        -H "Content-Type: application/json" \
        -d '{
            "model": "gpt-3.5-turbo",
            "prompt": "Generate a realistic Python library name for solar energy or photovoltaic systems. Examples: SolarSim, PVCore, PhotoVoltaic. Return only the name.",
            "max_tokens": 15,
            "temperature": 0.7
        }' | jq -r '.choices[0].text' | tr -d '\n' | xargs || echo "SolarAnalytics")
    
    # Generate scenario
    SCENARIO_PROMPT="Write a 2-3 sentence scenario about a solar energy researcher using $LIBRARY_NAME library for bifacial panel simulations and encountering errors with very low irradiance values."
    USE_CASE_SCENARIO=$(curl -s -X POST "$LLM_API_URL/v1/completions" \
        -H "Authorization: Bearer $LLM_API_KEY" \
        -H "Content-Type: application/json" \
        -d "{
            \"model\": \"gpt-3.5-turbo\",
            \"prompt\": \"$SCENARIO_PROMPT\",
            \"max_tokens\": 120,
            \"temperature\": 0.6
        }" | jq -r '.choices[0].text' | tr '\n' ' ' | xargs || echo "Default scenario")
else
    echo "⚠️  LLM not available, using fallback content..."
    LIBRARY_NAME="SolarAnalytics"
    USE_CASE_SCENARIO="A solar energy researcher is using $LIBRARY_NAME for bifacial panel simulations across different times of day. During sunrise and sunset periods with very low effective irradiance values, the simulation crashes with ValueError exceptions in the golden section search algorithm. The researcher needs to process large datasets covering full daily cycles without manual filtering of edge cases."
fi

# Escape for sed
LIBRARY_NAME_ESCAPED=$(echo "$LIBRARY_NAME" | sed 's/[[\.*^$()+?{|]/\\&/g')
USE_CASE_SCENARIO_ESCAPED=$(echo "$USE_CASE_SCENARIO" | sed 's/[[\.*^$()+?{|]/\\&/g')
HANDLER_TYPE_ESCAPED=$(echo "$HANDLER_TYPE" | sed 's/[[\.*^$()+?{|]/\\&/g')
LOG_LEVEL_ESCAPED=$(echo "$LOG_LEVEL" | sed 's/[[\.*^$()+?{|]/\\&/g')
TOLERANCE_PRECISION_ESCAPED=$(echo "$TOLERANCE_PRECISION" | sed 's/[[\.*^$()+?{|]/\\&/g')

echo "🏢 Library: $LIBRARY_NAME"

# Setup environment
echo "📦 Setting up environment..."
cp "$TEMPLATE_DIR/requirements.txt" requirements.txt
pip install -r requirements.txt > /dev/null 2>&1

# Create the problematic data file
echo "🔧 Setting up test environment..."

cat > failing_test_case.py << EOF
#!/usr/bin/env python3
"""
Reproduction script for the golden section search validation issue
"""

import numpy as np

# This is the problematic array from the issue report
problematic_v_oc = np.array([
    9.46949758e-16, -8.43546518e-15, 2.61042547e-15, 3.82769773e-15,
    1.01292315e-15, 4.81308106e+01, 5.12484772e+01, 5.22675087e+01,
    5.20708941e+01, 5.16481028e+01, 5.12364071e+01, 5.09209060e+01,
    5.09076598e+01, 5.10187680e+01, 5.11328118e+01, 5.13997628e+01,
    5.15121386e+01, 5.05621451e+01, 4.80488068e+01, 7.18224446e-15,
    1.21386700e-14, 6.40136698e-16, 4.36081007e-16, 6.51236255e-15
])

# Edge case parameters
effective_irradiance = 1.341083e-17
temp_cell = 13.7

print(f"Problematic v_oc values:")
print(f"Min value: {np.min(problematic_v_oc)}")
print(f"Values close to zero: {np.sum(np.abs(problematic_v_oc) < 1e-10)}")
print(f"Negative values: {np.sum(problematic_v_oc < 0)}")
EOF

# Create test configuration
cat > test_config.json << EOF
{
    "handler_type": "$HANDLER_TYPE",
    "log_level": "$LOG_LEVEL",
    "module_complexity": $MODULE_COMPLEXITY,
    "tolerance_precision": "$TOLERANCE_PRECISION",
    "error_threshold": $ERROR_THRESHOLD,
    "library_name": "$LIBRARY_NAME",
    "test_scenarios": [
        {
            "name": "very_low_irradiance",
            "effective_irradiance": 1.341083e-17,
            "temp_cell": 13.7,
            "expected_behavior": "handle_gracefully"
        },
        {
            "name": "mixed_precision_array",
            "description": "Array with very small positive and negative values",
            "expected_behavior": "process_without_error"
        }
    ]
}
EOF

# Process templates
echo "📝 Processing templates..."

# Process README.md
sed -e "s/{{library_name}}/$LIBRARY_NAME_ESCAPED/g" \
    -e "s/{{use_case_scenario}}/$USE_CASE_SCENARIO_ESCAPED/g" \
    -e "s/{{handler_type}}/$HANDLER_TYPE_ESCAPED/g" \
    -e "s/{{log_level}}/$LOG_LEVEL_ESCAPED/g" \
    -e "s/{{current_date}}/$CURRENT_DATE/g" \
    "$TEMPLATE_DIR/README.md.template" > README.md

# Create submission metadata
cat > .submission_metadata.json << EOF
{
    "task_id": "PVLIB-GSS-$(date +%s)",
    "generation_time": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "parameters": {
        "handler_type": "$HANDLER_TYPE",
        "log_level": "$LOG_LEVEL",
        "tolerance_precision": "$TOLERANCE_PRECISION",
        "library_name": "$LIBRARY_NAME"
    },
    "issue_context": {
        "original_repo": "pvlib/pvlib-python",
        "issue_type": "numerical_validation_too_strict",
        "affected_functions": ["_golden_sect_DataFrame", "_lambertw"]
    }
}
EOF

# Clean up templates
rm -rf "$TEMPLATE_DIR"
rm -rf "$CONFIG_DIR"

echo ""
echo "✅ PVLib Golden Section Search fix environment initialized!"
echo ""
echo "📋 Next steps:"
echo "   1. Read the problem description in README.md"
echo "   2. Review the failing test case: python failing_test_case.py"
echo "   3. Examine the current implementation in tools.py"
echo "   4. Implement your fix"
echo "   5. Add comprehensive tests"
echo "   6. Submit with: ./scripts/submit.sh"
echo ""
echo "🔬 Solar simulation debugging starts now! Good luck! ☀️"