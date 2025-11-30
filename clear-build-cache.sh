#!/bin/bash

# Скрипт для очистки кеша билда и перезапуска SweetPad

echo "🧹 Очистка кеша билда..."

# Очистка DerivedData для проекта Hohma
DERIVED_DATA_PATH="$HOME/Library/Developer/Xcode/DerivedData"
if [ -d "$DERIVED_DATA_PATH" ]; then
    echo "Удаление DerivedData для Hohma..."
    rm -rf "$DERIVED_DATA_PATH"/Hohma-*
    echo "✅ DerivedData очищен"
else
    echo "⚠️  DerivedData не найден"
fi

# Очистка модулей сборки
BUILD_ROOT="/Users/riqtu/Library/Developer/Xcode/DerivedData/Hohma-feyhsrwgwkhngxalgwrvimtxzndp"
if [ -d "$BUILD_ROOT" ]; then
    echo "Удаление build root..."
    rm -rf "$BUILD_ROOT"
    echo "✅ Build root очищен"
fi

# Очистка кеша SourceKit (если есть)
SOURCEKIT_CACHE="$HOME/Library/Caches/com.apple.dt.SourceKit"
if [ -d "$SOURCEKIT_CACHE" ]; then
    echo "Очистка кеша SourceKit..."
    rm -rf "$SOURCEKIT_CACHE"
    echo "✅ SourceKit cache очищен"
fi

echo ""
echo "✅ Кеш очищен!"
echo ""
echo "📝 Следующие шаги:"
echo "1. Перезапустите SweetPad extension в VS Code (Command Palette -> 'SweetPad: Restart Language Server')"
echo "2. Или перезапустите VS Code полностью"
echo ""

