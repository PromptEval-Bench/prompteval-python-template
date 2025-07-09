import csv
import zipfile
from pathlib import Path
import pandas as pd

from sklearn.model_selection import train_test_split

def prepare(raw: Path, public: Path, private: Path):
    """
    Processes the raw downloaded Kaggle data to create a custom, robust
    train/test split for the benchmark.
    """
    print("   Running data preparation script...")
    
    # --- Step 1: Extract raw data ---
    # The init script already unzips the main file. We just read the CSVs.
    print(f"      Reading raw training data from {raw / 'en_train.csv'}")
    old_train = pd.read_csv(raw / "en_train.csv")

    # --- Step 2: Create a new train/test split ---
    # We split so that we don't share any sentence_ids between train and test.
    # This is more robust than the original Kaggle split.
    print("      Creating new train/test split based on sentence_id...")
    unique_sentence_ids = old_train["sentence_id"].unique()
    train_sentence_ids, test_sentence_ids = train_test_split(
        unique_sentence_ids, test_size=0.1, random_state=42
    )
    new_train = old_train[old_train["sentence_id"].isin(train_sentence_ids)].copy()
    answers = old_train[old_train["sentence_id"].isin(test_sentence_ids)].copy()
    
    assert set(new_train["sentence_id"]).isdisjoint(set(answers["sentence_id"])), \
        "sentence_id is not disjoint between train and test sets"

    # --- Step 3: Re-index sentence_ids to be contiguous ---
    new_train_id_mapping = {old_id: new_id for new_id, old_id in enumerate(new_train["sentence_id"].unique())}
    new_train.loc[:, "sentence_id"] = new_train["sentence_id"].map(new_train_id_mapping)
    
    answers_id_mapping = {old_id: new_id for new_id, old_id in enumerate(answers["sentence_id"].unique())}
    answers.loc[:, "sentence_id"] = answers["sentence_id"].map(answers_id_mapping)

    # --- Step 4: Create the new test set and format the private answers ---
    new_test = answers.drop(["after", "class"], axis=1).copy()
    
    answers_formatted = answers[["sentence_id", "token_id", "after"]].copy()
    answers_formatted["id"] = answers_formatted["sentence_id"].astype(str) + "_" + answers_formatted["token_id"].astype(str)
    answers_formatted = answers_formatted[["id", "after"]]

    # --- Step 5: Create a new sample submission file ---
    sample_submission = new_test[["sentence_id", "token_id", "before"]].copy()
    sample_submission["id"] = sample_submission["sentence_id"].astype(str) + "_" + sample_submission["token_id"].astype(str)
    sample_submission["after"] = sample_submission["before"]
    sample_submission = sample_submission[["id", "after"]]

    # --- Step 6: Write files to public and private directories ---
    print("      Writing processed files to public and private directories...")
    # Private files (for backend evaluation)
    answers_formatted.to_csv(private / "answers.csv", index=False, quotechar='"', quoting=csv.QUOTE_NONNUMERIC)
    
    # Public files (for the user)
    public_train_path = public / "en_train.csv"
    public_test_path = public / "en_test.csv"
    public_submission_path = public / "en_sample_submission.csv"

    new_train.to_csv(public_train_path, index=False, quotechar='"', quoting=csv.QUOTE_NONNUMERIC)
    new_test.to_csv(public_test_path, index=False, quotechar='"', quoting=csv.QUOTE_NONNUMERIC)
    sample_submission.to_csv(public_submission_path, index=False, quotechar='"', quoting=csv.QUOTE_NONNUMERIC)

    # --- Step 7: Zip up public files for distribution ---
    print("      Zipping public files...")
    with zipfile.ZipFile(public / "en_train.csv.zip", "w", zipfile.ZIP_DEFLATED) as zipf:
        zipf.write(public_train_path, arcname="en_train.csv")
    with zipfile.ZipFile(public / "en_test.csv.zip", "w", zipfile.ZIP_DEFLATED) as zipf:
        zipf.write(public_test_path, arcname="en_test.csv")
    with zipfile.ZipFile(public / "en_sample_submission.csv.zip", "w", zipfile.ZIP_DEFLATED) as zipf:
        zipf.write(public_submission_path, arcname="en_sample_submission.csv")

    # Clean up the unzipped public files
    public_train_path.unlink()
    public_test_path.unlink()
    public_submission_path.unlink()
    
    print("   ✅ Data preparation complete.")