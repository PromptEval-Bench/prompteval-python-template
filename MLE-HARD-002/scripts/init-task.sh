#!/bin/bash
# Denoising Dirty Documents Task Initialization Script

set -e  # Exit on error

echo "🚀 Initializing Denoising Dirty Documents Challenge..."

# Basic setup
sudo apt-get update > /dev/null 2>&1
sudo apt-get install -y bc jq curl python3-pip > /dev/null 2>&1

# Load configuration
CONFIG_DIR="config"
TEMPLATE_DIR="template"

# Generate random parameters
RANDOM_SEED=$((RANDOM % 59 + 42))

echo "📊 Generated parameters:"
echo "   - Random seed: $RANDOM_SEED"

# Generate current date
CURRENT_DATE=$(date +%Y-%m-%d)

# LLM content generation (with fallbacks)
if [ ! -z "$LLM_API_URL" ] && [ ! -z "$LLM_API_KEY" ]; then
    echo "🤖 Generating dynamic content with LLM..."
    
    APPLICATION_NAME=$(curl -s -X POST "$LLM_API_URL/v1/completions" \
        -H "Authorization: Bearer $LLM_API_KEY" \
        -H "Content-Type: application/json" \
        -d '{
            "model": "gpt-3.5-turbo",
            "prompt": "Generate a realistic document processing application name. Examples: DocuClean, TextRestore, ScanFix, ClearText. Return only the application name, nothing else.",
            "max_tokens": 15,
            "temperature": 0.8
        }' | jq -r '.choices[0].text' | tr -d '\n' | xargs 2>/dev/null || echo "DocuClean")
    
    SCENARIO_PROMPT="Write a 2-3 sentence business scenario about how $APPLICATION_NAME helps digitize old documents by removing scanning artifacts and noise from text images. Include specific benefits like improved OCR accuracy and document preservation."
    USE_CASE_SCENARIO=$(curl -s -X POST "$LLM_API_URL/v1/completions" \
        -H "Authorization: Bearer $LLM_API_KEY" \
        -H "Content-Type: application/json" \
        -d "{
            \"model\": \"gpt-3.5-turbo\",
            \"prompt\": \"$SCENARIO_PROMPT\",
            \"max_tokens\": 120,
            \"temperature\": 0.6
        }" | jq -r '.choices[0].text' | tr '\n' ' ' | xargs 2>/dev/null || echo "Default scenario")
    
    DENOISING_TECHNIQUE=$(curl -s -X POST "$LLM_API_URL/v1/completions" \
        -H "Authorization: Bearer $LLM_API_KEY" \
        -H "Content-Type: application/json" \
        -d '{
            "model": "gpt-3.5-turbo",
            "prompt": "Suggest an image denoising technique for text documents. Examples: Gaussian filtering, bilateral filtering, median filtering, morphological operations. Return only the technique name.",
            "max_tokens": 20,
            "temperature": 0.5
        }' | jq -r '.choices[0].text' | tr -d '\n' | xargs 2>/dev/null || echo "Gaussian filtering")
    
    PREPROCESSING_STEP=$(curl -s -X POST "$LLM_API_URL/v1/completions" \
        -H "Authorization: Bearer $LLM_API_KEY" \
        -H "Content-Type: application/json" \
        -d '{
            "model": "gpt-3.5-turbo",
            "prompt": "Suggest one preprocessing step for noisy text images. Examples: histogram equalization, adaptive thresholding, edge preservation, contrast enhancement. Return only the step name.",
            "max_tokens": 15,
            "temperature": 0.4
        }' | jq -r '.choices[0].text' | tr -d '\n' | xargs 2>/dev/null || echo "histogram equalization")
else
    echo "⚠️  LLM not available, using fallback content..."
    APPLICATION_NAME="DocuClean"
    USE_CASE_SCENARIO="$APPLICATION_NAME revolutionizes document digitization by automatically removing scanning artifacts and noise from historical text images. The system significantly improves OCR accuracy rates and preserves valuable documents for future generations, making legacy archives searchable and accessible."
    DENOISING_TECHNIQUE="Gaussian filtering"
    PREPROCESSING_STEP="histogram equalization"
fi

# Escape for sed
APPLICATION_NAME_ESCAPED=$(echo "$APPLICATION_NAME" | sed 's/[[\.*^$()+?{|]/\\&/g')
USE_CASE_SCENARIO_ESCAPED=$(echo "$USE_CASE_SCENARIO" | sed 's/[[\.*^$()+?{|]/\\&/g')
DENOISING_TECHNIQUE_ESCAPED=$(echo "$DENOISING_TECHNIQUE" | sed 's/[[\.*^$()+?{|]/\\&/g')
PREPROCESSING_STEP_ESCAPED=$(echo "$PREPROCESSING_STEP" | sed 's/[[\.*^$()+?{|]/\\&/g')

echo "🖼️ Application: $APPLICATION_NAME"

# Setup Python environment
echo "📦 Setting up Python environment..."
pip install -r template/requirements.txt > /dev/null 2>&1

# Check Kaggle credentials
echo "🔑 Checking Kaggle credentials..."
if [ -z "$KAGGLE_USERNAME" ] || [ -z "$KAGGLE_KEY" ]; then
    echo "❌ FAILED: Kaggle credentials not found!"
    echo ""
    echo "Required environment variables:"
    echo "   - KAGGLE_USERNAME: Your Kaggle username"
    echo "   - KAGGLE_KEY: Your Kaggle API key"
    exit 1
fi

echo "   ✅ Found Kaggle credentials"

# Setup Kaggle credentials temporarily
mkdir -p ~/.kaggle
echo "{\"username\":\"$KAGGLE_USERNAME\",\"key\":\"$KAGGLE_KEY\"}" > ~/.kaggle/kaggle.json
chmod 600 ~/.kaggle/kaggle.json

# Download dataset
echo "📊 Downloading dataset from Kaggle..."
mkdir -p data/raw data/public data/private

if kaggle competitions download -c denoising-dirty-documents -p data/raw/ 2>/dev/null; then
    echo "   ✅ Successfully downloaded from Kaggle"
    
    cd data/raw
    if [ -f "denoising-dirty-documents.zip" ]; then
        unzip -q denoising-dirty-documents.zip
        rm denoising-dirty-documents.zip
    fi
    cd ../..
else
    rm -f ~/.kaggle/kaggle.json
    rmdir ~/.kaggle 2>/dev/null || true
    echo "❌ FAILED: Could not download data from Kaggle!"
    echo "   The competition 'denoising-dirty-documents' may not be accessible"
    echo "   or your Kaggle credentials may be incorrect."
    exit 1
fi

# Clean up credentials
rm -f ~/.kaggle/kaggle.json
rmdir ~/.kaggle 2>/dev/null || true

# Prepare data using the prepare.py script
echo "   🔄 Preparing train/test split..."
if ! python3 scripts/prepare.py data/raw data/public data/private; then
    echo "❌ FAILED: Could not prepare dataset!"
    exit 1
fi

# Copy files to working directory
cp -r data/public/* ./

# Process templates
echo "📝 Processing templates..."

sed -e "s/{{application_name}}/$APPLICATION_NAME_ESCAPED/g" \
    -e "s/{{use_case_scenario}}/$USE_CASE_SCENARIO_ESCAPED/g" \
    -e "s/{{denoising_technique}}/$DENOISING_TECHNIQUE_ESCAPED/g" \
    -e "s/{{preprocessing_step}}/$PREPROCESSING_STEP_ESCAPED/g" \
    -e "s/{{current_date}}/$CURRENT_DATE/g" \
    "$TEMPLATE_DIR/README.md.template" > README.md

sed -e "s/{{application_name}}/$APPLICATION_NAME_ESCAPED/g" \
    -e "s/{{current_date}}/$CURRENT_DATE/g" \
    -e "s/{{random_seed}}/$RANDOM_SEED/g" \
    "$TEMPLATE_DIR/starter_code.py.template" > starter_code.py

# Create exploration script
cat > explore_data.py << 'EOF'
#!/usr/bin/env python3
import numpy as np
import cv2
import matplotlib.pyplot as plt
from pathlib import Path

def explore_dataset():
    print("🔍 Denoising Dirty Documents Dataset Explorer")
    print("=" * 60)
    
    # Check directories
    dirs = ['train', 'train_cleaned', 'test']
    for directory in dirs:
        path = Path(directory)
        if path.exists():
            count = len(list(path.glob('*.png')))
            print(f"📁 {directory}: {count} images")
        else:
            print(f"❌ {directory}: Not found")
    
    # Load and analyze sample images
    train_path = Path('train')
    clean_path = Path('train_cleaned')
    
    if train_path.exists() and clean_path.exists():
        train_files = sorted(list(train_path.glob('*.png')))
        clean_files = sorted(list(clean_path.glob('*.png')))
        
        if train_files and clean_files:
            # Load first few images
            fig, axes = plt.subplots(3, 3, figsize=(15, 12))
            
            for i in range(min(3, len(train_files))):
                # Load images
                noisy_img = cv2.imread(str(train_files[i]), cv2.IMREAD_GRAYSCALE)
                clean_img = cv2.imread(str(clean_files[i]), cv2.IMREAD_GRAYSCALE)
                
                if noisy_img is not None and clean_img is not None:
                    # Calculate difference
                    diff = np.abs(noisy_img.astype(float) - clean_img.astype(float))
                    
                    # Display images
                    axes[i, 0].imshow(noisy_img, cmap='gray')
                    axes[i, 0].set_title(f'Noisy Document {i+1}')
                    axes[i, 0].axis('off')
                    
                    axes[i, 1].imshow(clean_img, cmap='gray')
                    axes[i, 1].set_title(f'Clean Document {i+1}')
                    axes[i, 1].axis('off')
                    
                    axes[i, 2].imshow(diff, cmap='hot')
                    axes[i, 2].set_title(f'Noise Pattern {i+1}')
                    axes[i, 2].axis('off')
                    
                    if i == 0:
                        print(f"\n📊 Image {i+1} Properties:")
                        print(f"   Shape: {noisy_img.shape}")
                        print(f"   Noisy range: [{noisy_img.min()}, {noisy_img.max()}]")
                        print(f"   Clean range: [{clean_img.min()}, {clean_img.max()}]")
                        print(f"   Noise std: {diff.std():.2f}")
            
            plt.tight_layout()
            plt.savefig('document_analysis.png', dpi=150, bbox_inches='tight')
            print(f"\n💾 Document analysis saved to 'document_analysis.png'")
            
            # Show noise statistics
            print(f"\n📈 Noise Analysis:")
            total_diff = 0
            total_pixels = 0
            
            for i in range(min(5, len(train_files))):
                noisy = cv2.imread(str(train_files[i]), cv2.IMREAD_GRAYSCALE)
                clean = cv2.imread(str(clean_files[i]), cv2.IMREAD_GRAYSCALE)
                
                if noisy is not None and clean is not None:
                    diff = np.abs(noisy.astype(float) - clean.astype(float))
                    total_diff += diff.sum()
                    total_pixels += diff.size
            
            if total_pixels > 0:
                avg_noise = total_diff / total_pixels
                print(f"   Average noise level: {avg_noise:.2f}")
    
    print(f"\n🎯 Your Task:")
    print(f"   Remove noise from historical documents to minimize RMSE")
    print(f"   Output format: pixel-level predictions in CSV")
    print(f"   Focus on preserving text while removing background artifacts")

if __name__ == "__main__":
    explore_dataset()
EOF

chmod +x explore_data.py

# Create metadata files
cat > .submission_metadata.json << EOF
{
    "task_id": "CV-HARD-003-$(date +%s)",
    "generation_time": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "parameters": {
        "random_seed": $RANDOM_SEED,
        "application_name": "$APPLICATION_NAME"
    },
    "dataset_info": {
        "task_type": "image_denoising",
        "metric": "rmse",
        "source": "kaggle_denoising_dirty_documents"
    }
}
EOF

cp "$CONFIG_DIR/task_metadata.json" .task_metadata.json

# Cleanup
rm -rf "$CONFIG_DIR" "$TEMPLATE_DIR"

echo ""
echo "✅ Denoising Dirty Documents challenge initialized successfully!"
echo ""
echo "📋 Next steps:"
echo "   1. Explore the dataset: python explore_data.py"
echo "   2. Read the challenge description in README.md"
echo "   3. Run the starter code: python starter_code.py"
echo "   4. Implement your document denoising algorithm"
echo "   5. Submit with: ./scripts/submit.sh"
echo ""
echo "🖼️ Help preserve historical documents! Good luck!"