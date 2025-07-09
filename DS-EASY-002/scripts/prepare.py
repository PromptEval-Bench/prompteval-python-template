import pandas as pd
import numpy as np
from pathlib import Path
from sklearn.model_selection import train_test_split

def prepare(raw: Path, public: Path, private: Path):
    """
    Processes the raw Kaggle train.csv to create a new, robust train/test split.
    """
    print("   Running data preparation script for Manufacturing State Prediction...")

    # --- Step 1: Load Raw Data ---
    print(f"      Reading raw data from {raw / 'train.csv'}...")
    old_train = pd.read_csv(raw / "train.csv")

    # --- Step 2: Create New Train/Test Split ---
    # The original test set is unlabelled. We create our own from the labelled training data.
    # This creates a test set of 100,000 samples.
    print("      Creating new train/test split (test_size=100,000)...")
    new_train, new_test_with_labels = train_test_split(
        old_train, test_size=100_000, random_state=42, stratify=old_train['target']
    )

    # --- Step 3: Re-index IDs to be contiguous and non-overlapping ---
    print("      Re-indexing IDs...")
    new_train['id'] = np.arange(len(new_train))
    new_test_with_labels['id'] = np.arange(len(new_train), len(new_train) + len(new_test_with_labels))

    # --- Step 4: Create public and private files ---
    # Public test set (for the user, without labels)
    public_test = new_test_with_labels.drop(columns=["target"]).copy()
    
    # Private answer key
    private_answers = new_test_with_labels[["id", "target"]].copy()
    
    # Sample submission file
    sample_submission = private_answers.copy()
    sample_submission['target'] = 0.5

    # --- Step 5: Save all files ---
    print("      Writing final public and private files...")
    new_train.to_csv(public / "train.csv", index=False)
    public_test.to_csv(public / "test.csv", index=False)
    sample_submission.to_csv(public / "sample_submission.csv", index=False)
    private_answers.to_csv(private / "answers.csv", index=False) # Renamed for clarity

    print("   ✅ Data preparation complete.")