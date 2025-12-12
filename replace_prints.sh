#!/bin/bash

# Скрипт для замены print() на AppLogger
# Использование: ./replace_prints.sh

# Функция для замены print с эмодзи на соответствующий уровень логирования
replace_print() {
    local file="$1"
    
    # Заменяем print с ❌ на error
    sed -i '' 's/print("❌ \([^"]*\)")/AppLogger.shared.error("\1", category: .general)/g' "$file"
    sed -i '' "s/print(\"❌ \([^\"]*\)\")/AppLogger.shared.error(\"\\1\", category: .general)/g" "$file"
    
    # Заменяем print с ⚠️ на warning
    sed -i '' 's/print("⚠️ \([^"]*\)")/AppLogger.shared.warning("\1", category: .general)/g' "$file"
    sed -i '' "s/print(\"⚠️ \([^\"]*\)\")/AppLogger.shared.warning(\"\\1\", category: .general)/g" "$file"
    
    # Заменяем print с ✅ на info
    sed -i '' 's/print("✅ \([^"]*\)")/AppLogger.shared.info("\1", category: .general)/g' "$file"
    sed -i '' "s/print(\"✅ \([^\"]*\)\")/AppLogger.shared.info(\"\\1\", category: .general)/g" "$file"
    
    # Заменяем остальные print на debug
    sed -i '' 's/print("\([^"]*\)")/AppLogger.shared.debug("\1", category: .general)/g' "$file"
    sed -i '' "s/print(\"\([^\"]*\)\")/AppLogger.shared.debug(\"\\1\", category: .general)/g" "$file"
}

echo "⚠️  ВНИМАНИЕ: Этот скрипт делает массовую замену и может заменить не все случаи правильно!"
echo "Рекомендуется делать замену вручную для каждого файла."
echo ""
echo "Продолжить? (y/n)"
read -r answer

if [ "$answer" != "y" ]; then
    echo "Отменено."
    exit 0
fi

# Находим все Swift файлы с print()
find Hohma -name "*.swift" -type f | while read -r file; do
    if grep -q "print(" "$file"; then
        echo "Обрабатываю: $file"
        # replace_print "$file"
    fi
done

echo "Готово!"

