#!/bin/bash

filepath="$SRCROOT/Hohma/Features/Auth/Views/AuthView.swift"
filename=$(basename "$filepath")
tempfile="$filepath.tmp"

echo "Processing: $filename"

# Check if the file should be processed
if [[ $(grep -c ": View {" "$filepath") -eq 0 ]]; then
    echo "Skipping: $filename (No \": View {\" found)"
    exit 0
fi

echo "File contains \": View {\" - processing..."

# Create a temporary file for modifications
cp "$filepath" "$tempfile"

# 1. Add import Inject if needed
if ! grep -q "import Inject" "$tempfile"; then
    echo "Adding import Inject..."
    sed -i "" -e "/^import SwiftUI/a\
import Inject" "$tempfile"
else
    echo "import Inject already exists"
fi

# 2. Add @ObserveInjection var inject if needed
if ! grep -q "@ObserveInjection var inject" "$tempfile"; then
    echo "Adding @ObserveInjection var inject..."
    sed -i "" -e "/struct.*: View {/a\
    @ObserveInjection var inject" "$tempfile"
else
    echo "@ObserveInjection var inject already exists"
fi

# Check if modifications were made
if ! cmp -s "$filepath" "$tempfile"; then
    echo "Changes detected - updating file"
    mv "$tempfile" "$filepath"
else
    echo "No changes needed"
fi

rm -f "$tempfile"
echo "Processing completed for $filename"

