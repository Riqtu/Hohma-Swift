#!/bin/bash

# Test script to check if files are found and processed
echo "Testing script execution..."

# Check if we can find Swift files
echo "Looking for Swift files in $SRCROOT/Hohma:"
find "$SRCROOT/Hohma" -name "*.swift" | head -3

# Check if we can find View files
echo "Looking for View files:"
find "$SRCROOT/Hohma" -name "*.swift" -exec grep -l ": View {" {} \; | head -3

echo "Test completed."

