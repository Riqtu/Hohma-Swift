#!/bin/bash

echo "Testing file permissions..."

# Test if we can read files
echo "Testing read access:"
if [ -r "$SRCROOT/Hohma/Features/Auth/Views/AuthView.swift" ]; then
    echo "✓ Can read AuthView.swift"
else
    echo "✗ Cannot read AuthView.swift"
fi

# Test if we can write to files
echo "Testing write access:"
if [ -w "$SRCROOT/Hohma/Features/Auth/Views/AuthView.swift" ]; then
    echo "✓ Can write to AuthView.swift"
else
    echo "✗ Cannot write to AuthView.swift"
fi

# Test if we can create temporary files
echo "Testing temp file creation:"
tempfile="$SRCROOT/Hohma/Features/Auth/Views/AuthView.swift.test"
if touch "$tempfile" 2>/dev/null; then
    echo "✓ Can create temp files"
    rm "$tempfile"
else
    echo "✗ Cannot create temp files"
fi

# Test current working directory
echo "Current working directory: $(pwd)"
echo "SRCROOT: $SRCROOT"

# Test if we can find files
echo "Testing file discovery:"
find "$SRCROOT/Hohma" -name "*.swift" | head -3

echo "Permission test completed."

