#!/bin/bash
# Project Initialization Engine - MLE-EASY-002

set -e
set -o pipefail

# --- 1. Setup Environment and Paths ---
echo "🚀 Initializing Project Environment: Manufacturing State Prediction..."
cd "$(dirname "$0")/.."

# Install tools
sudo apt-get update > /dev/null 2>&1; sudo apt-get install -y jq curl unzip python3-pip > /dev/null 2>&1

TEMPLATE_DIR="template"

# --- 2. Generate Dynamic Content (Simplified) ---
echo "🤖 Generating dynamic narrative content..."
COMPANY_NAME="Precision Dynamics"
SYSTEM_NAME="ProcessGuard"
SCENARIO_CONTEXT="You are a Data Scientist at $COMPANY_NAME, a leader in smart manufacturing. We are developing '$SYSTEM_NAME', a new system to predict machine states in real-time. By predicting whether a machine is in a normal (0) or potential failure (1) state from sensor data, we can schedule preventative maintenance and avoid costly downtime. Your task is to build the core predictive model for this system."
MODEL_APPROACH_SUGGESTION="a LightGBM or XGBoost model, known for their performance and speed"
FEATURE_TECHNIQUE_SUGGESTION="one-hot encoding for the categorical features"
RANDOM_SEED=42
CURRENT_DATE=$(date +"%Y-%m-%d")

# --- 3. Setup Python Environment ---
echo "📦 Setting up Python environment..."
pip install -r "$TEMPLATE_DIR/requirements.txt" > /dev/null 2>&1

# --- 4. Kaggle Dataset Download & Processing ---
echo "🔑 Checking for Kaggle API credentials..."
if [ -z "$KAGGLE_USERNAME" ] || [ -z "$KAGGLE_KEY" ]; then echo "❌ ERROR: Kaggle credentials not found."; exit 1; fi
echo "   ✅ Kaggle credentials found."
mkdir -p ~/.kaggle; echo "{\"username\":\"$KAGGLE_USERNAME\",\"key\":\"$KAGGLE_KEY\"}" > ~/.kaggle/kaggle.json; chmod 600 ~/.kaggle/kaggle.json
mkdir -p data/raw data/public data/private
echo "📊 Downloading dataset 'tabular-playground-series-may-2022' from Kaggle..."
if kaggle competitions download -c tabular-playground-series-may-2022 -p data/raw/ 2>/dev/null; then
    echo "   ✅ Download successful. Unzipping raw data..."
    unzip -q -o data/raw/*.zip -d data/raw/
else
    rm -rf ~/.kaggle data; echo "❌ ERROR: Failed to download data from Kaggle."; exit 1
fi
rm -rf ~/.kaggle

# --- 5. Data Preparation ---
echo "⚙️  Processing data with prepare.py script..."
python3 scripts/prepare.py data/raw data/public data/private
echo "🚚 Moving final data files to project root..."
cp data/public/train.csv .
cp data/public/test.csv .
cp data/public/sample_submission.csv .
echo "🧹 Cleaning up temporary data directories..."
rm -rf data

# --- 6. Template Processing ---
echo "📝 Processing project templates..."
# README.md
sed -e "s/{{company_name}}/$COMPANY_NAME/g" \
    -e "s/{{system_name}}/$SYSTEM_NAME/g" \
    -e "s/{{scenario_context}}/$SCENARIO_CONTEXT/g" \
    -e "s/{{current_date}}/$CURRENT_DATE/g" \
    "$TEMPLATE_DIR/README.md.template" > README.md

# starter_code.py
sed -e "s/{{random_seed}}/$RANDOM_SEED/g" \
    -e "s/{{model_approach_suggestion}}/$MODEL_APPROACH_SUGGESTION/g" \
    -e "s/{{feature_technique_suggestion}}/$FEATURE_TECHNIQUE_SUGGESTION/g" \
    "$TEMPLATE_DIR/starter_code.py.template" > starter_code.py

# --- 7. Finalization ---
rm -rf "$TEMPLATE_DIR" config scripts/prepare.py

echo -e "\n✅ Project Environment Initialized Successfully!\n"
echo "--- NEXT STEPS ---"
echo "1. Read the project brief in README.md"
echo "2. Run the starter code to establish a baseline: python3 starter_code.py"
echo "3. Enhance the model in starter_code.py to improve the AUC score."
echo "4. Submit your predictions with: ./scripts/submit.sh"
echo "--------------------"