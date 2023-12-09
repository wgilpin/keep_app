#!/bin/bash

BASE_DIR="./chromeext"
cd $BASE_DIR

SOURCE_DIR="./templates"
OUT_DIR="build/prod"
rm -f ./$OUT_DIR/*
rmdir ./$OUT_DIR

# Create the build folder if it doesn't exist
mkdir -p "$OUT_DIR"

# Check if mustache is installed
if ! command -v mustache &>/dev/null; then
  # Install mustache
  npm install mustache
fi

# Iterate through the source folder
for file in "$SOURCE_DIR"/*; do
    if [[ -f "$file" ]]; then
        filename=$(basename "$file")
        extension="${filename##*.}"
        
        if [[ "$extension" == "mustache" ]]; then
            # Apply Mustache templating
            output_filename="${filename%.mustache}"
            
            npm exec mustache prod.json "$file" > ./"$OUT_DIR/$output_filename"
            echo "built  $OUT_DIR/$output_filename"
        else
            # Copy the file as is
            cp "$file" "$OUT_DIR/$filename"
            echo "copied $OUT_DIR/$filename"
        fi
    fi
done

pwd
tar -a -c -f ./$OUT_DIR/build.zip ./$OUT_DIR/*

echo "Done - build.zip saved to "$BASE_DIR"/"$OUT_DIR
