#!/bin/bash
# Material Property Prediction Task Initialization Script

set -e  # Exit on error

echo "🚀 Initializing Material Property Prediction Challenge..."

# Basic setup
sudo apt-get update > /dev/null 2>&1
sudo apt-get install -y bc jq curl > /dev/null 2>&1

# Load configuration
CONFIG_DIR="config"
TEMPLATE_DIR="template"

# Generate random parameters
RANDOM_SEED=$((RANDOM % 59 + 42))  # 42-100

echo "📊 Generated parameters:"
echo "   - Random seed: $RANDOM_SEED"

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
            "prompt": "Generate a realistic name for a computational materials science platform. Examples: MatMLab, CrystalPredict, MaterialsAI. Return only the name.",
            "max_tokens": 15,
            "temperature": 0.7
        }' | jq -r '.choices[0].text' | tr -d '\n' | xargs || echo "MaterialsAI")
    
    # Generate scenario
    SCENARIO_PROMPT="Write a 2-3 sentence scenario about a materials scientist using $LIBRARY_NAME to predict material properties from crystal structure data."
    USE_CASE_SCENARIO=$(curl -s -X POST "$LLM_API_URL/v1/completions" \
        -H "Authorization: Bearer $LLM_API_KEY" \
        -H "Content-Type: application/json" \
        -d "{
            \"model\": \"gpt-3.5-turbo\",
            \"prompt\": \"$SCENARIO_PROMPT\",
            \"max_tokens\": 120,
            \"temperature\": 0.6
        }" | jq -r '.choices[0].text' | tr '\n' ' ' | xargs || echo "Default scenario")
    
    # Generate approach
    MODEL_APPROACH=$(curl -s -X POST "$LLM_API_URL/v1/completions" \
        -H "Authorization: Bearer $LLM_API_KEY" \
        -H "Content-Type: application/json" \
        -d '{
            "model": "gpt-3.5-turbo",
            "prompt": "Suggest one ML approach for materials property prediction. Examples: ensemble methods, neural networks. One term only.",
            "max_tokens": 10,
            "temperature": 0.5
        }' | jq -r '.choices[0].text' | tr -d '\n' | xargs || echo "ensemble methods")
    
    # Generate feature engineering
    FEATURE_ENGINEERING=$(curl -s -X POST "$LLM_API_URL/v1/completions" \
        -H "Authorization: Bearer $LLM_API_KEY" \
        -H "Content-Type: application/json" \
        -d '{
            "model": "gpt-3.5-turbo",
            "prompt": "Suggest one feature engineering approach for crystalline materials. Examples: compositional, geometric. One word only.",
            "max_tokens": 8,
            "temperature": 0.4
        }' | jq -r '.choices[0].text' | tr -d '\n' | xargs || echo "structural")
else
    echo "⚠️  LLM not available, using fallback content..."
    LIBRARY_NAME="MaterialsAI"
    USE_CASE_SCENARIO="A materials scientist is using $LIBRARY_NAME to predict formation energy and bandgap properties from crystal structure data. The platform combines atomic composition and spatial coordinates to accelerate materials discovery for electronic applications."
    MODEL_APPROACH="ensemble methods"
    FEATURE_ENGINEERING="structural"
fi

# Escape for sed
LIBRARY_NAME_ESCAPED=$(echo "$LIBRARY_NAME" | sed 's/[[\.*^$()+?{|]/\\&/g')
USE_CASE_SCENARIO_ESCAPED=$(echo "$USE_CASE_SCENARIO" | sed 's/[[\.*^$()+?{|]/\\&/g')
MODEL_APPROACH_ESCAPED=$(echo "$MODEL_APPROACH" | sed 's/[[\.*^$()+?{|]/\\&/g')
FEATURE_ENGINEERING_ESCAPED=$(echo "$FEATURE_ENGINEERING" | sed 's/[[\.*^$()+?{|]/\\&/g')

echo "🏢 Library: $LIBRARY_NAME"

# Setup environment
echo "📦 Setting up environment..."
cp "$TEMPLATE_DIR/requirements.txt" requirements.txt
pip install -r requirements.txt > /dev/null 2>&1

# Data setup
echo "📊 Setting up dataset..."

# Check if data directory exists
DATA_SOURCE_DIR="data/nomad2018-predict-transparent-conductors"
if [ -d "$DATA_SOURCE_DIR" ]; then
    echo "   ✅ Data source found: $DATA_SOURCE_DIR"
    
    # Create dataset directory
    mkdir -p dataset
    
    # Copy key files to working directory
    if [ -f "$DATA_SOURCE_DIR/public/train.csv" ]; then
        cp "$DATA_SOURCE_DIR/public/train.csv" ./
        echo "   ✅ Copied train.csv"
    fi
    
    if [ -f "$DATA_SOURCE_DIR/public/test.csv" ]; then
        cp "$DATA_SOURCE_DIR/public/test.csv" ./
        echo "   ✅ Copied test.csv"
    fi
    
    if [ -f "$DATA_SOURCE_DIR/public/sample_submission.csv" ]; then
        cp "$DATA_SOURCE_DIR/public/sample_submission.csv" ./
        echo "   ✅ Copied sample_submission.csv"
    fi
    
    # Create symlinks for geometry directories if they exist
    if [ -d "$DATA_SOURCE_DIR/public/train" ]; then
        ln -sf "$(realpath $DATA_SOURCE_DIR/public/train)" ./dataset/train_geometry
        echo "   ✅ Linked train geometry directory"
    fi
    
    if [ -d "$DATA_SOURCE_DIR/public/test" ]; then
        ln -sf "$(realpath $DATA_SOURCE_DIR/public/test)" ./dataset/test_geometry
        echo "   ✅ Linked test geometry directory"
    fi
    
    # Create data info file
    TRAIN_COUNT=0
    TEST_COUNT=0
    if [ -f "train.csv" ]; then
        TRAIN_COUNT=$(tail -n +2 train.csv | wc -l 2>/dev/null || echo "0")
    fi
    if [ -f "test.csv" ]; then
        TEST_COUNT=$(tail -n +2 test.csv | wc -l 2>/dev/null || echo "0")
    fi
    
    cat > data_info.json << EOF
{
    "dataset_name": "NOMAD 2018 Transparent Conductors",
    "task_type": "regression",
    "targets": ["formation_energy_ev_natom", "bandgap_energy_ev"],
    "train_samples": $TRAIN_COUNT,
    "test_samples": $TEST_COUNT,
    "geometry_files": "Available in dataset/train_geometry/ and dataset/test_geometry/"
}
EOF

    echo "   📁 Dataset structure:"
    echo "      - train.csv: Training data with targets"
    echo "      - test.csv: Test data for predictions"
    echo "      - sample_submission.csv: Submission format example"
    echo "      - dataset/train_geometry/: XYZ geometry files for training"
    echo "      - dataset/test_geometry/: XYZ geometry files for testing"
    
    echo "   📊 Data summary:"
    echo "      - Training samples: $TRAIN_COUNT"
    echo "      - Test samples: $TEST_COUNT"
    
    # Check for geometry files (sample check)
    if [ -f "train.csv" ] && [ "$TRAIN_COUNT" -gt 0 ]; then
        FIRST_TRAIN_ID=$(tail -n +2 train.csv | head -n 1 | cut -d',' -f1)
        if [ -f "dataset/train_geometry/$FIRST_TRAIN_ID/geometry.xyz" ]; then
            echo "   ✅ Geometry files verified"
        else
            echo "   ⚠️  Warning: Geometry files may not be properly linked"
        fi
    fi
    
else
    echo "❌ Error: Data directory not found at $DATA_SOURCE_DIR"
    echo "Please ensure the data folder is placed in the correct location."
    exit 1
fi

# Create data exploration helper
cat > explore_data.py << 'EOF'
#!/usr/bin/env python3
"""
Quick data exploration script for the materials dataset
"""

import pandas as pd
import numpy as np
import os
import json

def explore_dataset():
    print("🔍 Material Property Prediction Dataset Explorer")
    print("=" * 60)
    
    # Load data info
    if os.path.exists('data_info.json'):
        with open('data_info.json', 'r') as f:
            data_info = json.load(f)
        
        print(f"📊 Dataset: {data_info['dataset_name']}")
        print(f"📈 Task: {data_info['task_type']} - {data_info['targets']}")
    
    # Load CSV files
    if os.path.exists('train.csv') and os.path.exists('test.csv'):
        train_df = pd.read_csv('train.csv')
        test_df = pd.read_csv('test.csv')
        
        print(f"\n📁 Data Shape:")
        print(f"   Training: {train_df.shape}")
        print(f"   Test: {test_df.shape}")
        
        # Basic statistics
        print(f"\n📊 Target Statistics:")
        for target in ['formation_energy_ev_natom', 'bandgap_energy_ev']:
            if target in train_df.columns:
                values = train_df[target].dropna()
                print(f"   {target}:")
                print(f"      Mean: {values.mean():.4f}")
                print(f"      Std: {values.std():.4f}")
                print(f"      Range: [{values.min():.4f}, {values.max():.4f}]")
        
        # Feature overview
        print(f"\n🔧 Features Overview:")
        feature_cols = [col for col in train_df.columns if col not in ['id', 'formation_energy_ev_natom', 'bandgap_energy_ev']]
        for col in feature_cols:
            print(f"   {col}: {train_df[col].dtype}")
        
        # Check for missing values
        missing_train = train_df.isnull().sum().sum()
        missing_test = test_df.isnull().sum().sum()
        print(f"\n❓ Missing Values:")
        print(f"   Training: {missing_train}")
        print(f"   Test: {missing_test}")
        
        # Geometry files check
        sample_id = train_df.iloc[0]['id']
        geometry_path = f"dataset/train_geometry/{sample_id}/geometry.xyz"
        if os.path.exists(geometry_path):
            print(f"\n🧪 Geometry Data Sample (ID: {sample_id}):")
            with open(geometry_path, 'r') as f:
                lines = f.readlines()
                print(f"   Atoms: {lines[0].strip()}")
                print(f"   Format: XYZ coordinates")
                if len(lines) > 2:
                    print(f"   First atom: {lines[2].strip()}")
    else:
        print("❌ CSV files not found")
    
    print(f"\n🎯 Your Task:")
    print(f"   Predict formation_energy_ev_natom and bandgap_energy_ev")
    print(f"   Use material properties + 3D geometry information")
    print(f"   Submit in the required CSV format")

if __name__ == "__main__":
    explore_dataset()
EOF

chmod +x explore_data.py

# Process templates
echo "📝 Processing templates..."

# Process README.md
sed -e "s/{{library_name}}/$LIBRARY_NAME_ESCAPED/g" \
    -e "s/{{use_case_scenario}}/$USE_CASE_SCENARIO_ESCAPED/g" \
    -e "s/{{model_approach}}/$MODEL_APPROACH_ESCAPED/g" \
    -e "s/{{feature_engineering}}/$FEATURE_ENGINEERING_ESCAPED/g" \
    -e "s/{{current_date}}/$CURRENT_DATE/g" \
    "$TEMPLATE_DIR/README.md.template" > README.md

# Process starter_code.py
sed -e "s/{{library_name}}/$LIBRARY_NAME_ESCAPED/g" \
    -e "s/{{current_date}}/$CURRENT_DATE/g" \
    -e "s/{{random_seed}}/$RANDOM_SEED/g" \
    "$TEMPLATE_DIR/starter_code.py.template" > starter_code.py

# Create submission metadata
cat > .submission_metadata.json << EOF
{
    "task_id": "MATERIALS-$(date +%s)",
    "generation_time": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "parameters": {
        "random_seed": $RANDOM_SEED,
        "library_name": "$LIBRARY_NAME"
    },
    "dataset_info": {
        "source": "MLE-Bench NOMAD 2018",
        "task_type": "multi_target_regression",
        "targets": ["formation_energy_ev_natom", "bandgap_energy_ev"]
    }
}
EOF

# Clean up templates
rm -rf "$TEMPLATE_DIR"
rm -rf "$CONFIG_DIR"

echo ""
echo "✅ Material Property Prediction environment initialized!"
echo ""
echo "📋 Next steps:"
echo "   1. Explore the dataset: python explore_data.py"
echo "   2. Read the problem description in README.md"  
echo "   3. Examine training data: python starter_code.py"
echo "   4. Build your prediction model"
echo "   5. Submit with: ./scripts/submit.sh"
echo ""
echo "🧪 Materials science modeling starts now! Good luck! ⚗️"