#!/bin/bash
# Project Initialization Engine - MLE-EASY-001 (v2)

set -e
set -o pipefail

# --- 1. Setup Environment and Paths ---
echo "🚀 Initializing Project Environment: Text Normalization..."
cd "$(dirname "$0")/.."

# Install necessary tools quietly
sudo apt-get update > /dev/null 2>&1
sudo apt-get install -y jq curl unzip python3-pip > /dev/null 2>&1

CONFIG_DIR="config"
TEMPLATE_DIR="template"

# --- 2. Load Configs and Generate Dynamic Content ---
echo "🤖 Generating dynamic content from configuration..."
PARAMS_JSON=$(cat "$CONFIG_DIR/dynamic_params.json")
# (For brevity, using fallbacks. A full implementation would use the generic LLM engine)
COMPANY_NAME="Vocalia AI"
PRODUCT_NAME="Nexus Voice"
SCENARIO_CONTEXT="You are a Machine Learning Engineer at $COMPANY_NAME, working on our next-generation voice assistant, $PRODUCT_NAME. A key feature is making $PRODUCT_NAME sound natural. This requires a robust Text Normalization Unit (TNU) to convert written text with symbols, numbers, and abbreviations into their proper spoken form before it reaches the speech synthesis engine. Your task is to build the core model for this TNU."
MODEL_APPROACH="a Transformer-based model (like T5)"
FEATURE_TECHNIQUE="Part-of-speech tagging"
RANDOM_SEED=$(echo "$PARAMS_JSON" | jq -r '.rule_based_params.random_seed.min') # Simplified
CURRENT_DATE=$(date +"%Y-%m-%d")

# --- 3. Setup Python Environment ---
echo "📦 Setting up Python environment..."
pip install -r "$TEMPLATE_DIR/requirements.txt" > /dev/null 2>&1

# --- 4. Kaggle Dataset Download & Processing ---
# (This section remains the same as the previous response)
echo "🔑 Checking for Kaggle API credentials..."
if [ -z "$KAGGLE_USERNAME" ] || [ -z "$KAGGLE_KEY" ]; then echo "❌ ERROR: Kaggle credentials not found."; exit 1; fi
echo "   ✅ Kaggle credentials found."
mkdir -p ~/.kaggle; echo "{\"username\":\"$KAGGLE_USERNAME\",\"key\":\"$KAGGLE_KEY\"}" > ~/.kaggle/kaggle.json; chmod 600 ~/.kaggle/kaggle.json
mkdir -p data/raw data/public data/private
echo "📊 Downloading dataset from Kaggle..."
if kaggle competitions download -c text-normalization-challenge-english-language -p data/raw/ 2>/dev/null; then
    echo "   ✅ Download successful. Unzipping raw data..."
    unzip -q -o data/raw/*.zip -d data/raw/
else
    rm -rf ~/.kaggle data; echo "❌ ERROR: Failed to download data from Kaggle."; exit 1
fi
rm -rf ~/.kaggle
echo "⚙️  Processing data with prepare.py script..."
python3 scripts/prepare.py data/raw data/public data/private
echo "🚚 Moving final data files to project root..."
cp data/public/*.zip .
echo "🧹 Cleaning up temporary data directories..."
rm -rf data

# --- 5. Template Processing ---
echo "📝 Processing project templates..."
# README.md
readme_content=$(cat "$TEMPLATE_DIR/README.md.template")
readme_content="${readme_content//\{\{company_name\}\}/$COMPANY_NAME}"
readme_content="${readme_content//\{\{product_name\}\}/$PRODUCT_NAME}"
readme_content="${readme_content//\{\{scenario_context\}\}/$SCENARIO_CONTEXT}"
readme_content="${readme_content//\{\{current_date\}\}/$CURRENT_DATE}"
echo "$readme_content" > README.md

# starter_code.py (from template)
echo "   Processing starter_code.py.template..."
starter_code_content=$(cat "$TEMPLATE_DIR/starter_code.py.template")
starter_code_content="${starter_code_content//\{\{company_name\}\}/$COMPANY_NAME}"
starter_code_content="${starter_code_content//\{\{product_name\}\}/$PRODUCT_NAME}"
starter_code_content="${starter_code_content//\{\{current_date\}\}/$CURRENT_DATE}"
starter_code_content="${starter_code_content//\{\{random_seed\}\}/$RANDOM_SEED}"
starter_code_content="${starter_code_content//\{\{model_approach\}\}/$MODEL_APPROACH}"
starter_code_content="${starter_code_content//\{\{feature_technique\}\}/$FEATURE_TECHNIQUE}"
echo "$starter_code_content" > starter_code.py

# --- 6. Finalization ---
# Clean up all temporary/source files
rm -rf "$TEMPLATE_DIR"
rm -rf config
rm scripts/prepare.py

echo ""
echo "✅ Project Environment Initialized Successfully!"
echo ""
echo "--- NEXT STEPS ---"
echo "1. Read the project brief in README.md"
echo "2. Examine the complete pipeline in starter_code.py"
echo "3. Run the baseline: python3 starter_code.py"
echo "4. Implement your advanced model in starter_code.py to improve the score."
echo "5. Submit your results with: ./scripts/submit.sh"
echo "--------------------"