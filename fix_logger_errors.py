#!/usr/bin/env python3
"""
Скрипт для исправления ошибок в AppLogger вызовах
Исправляет строки с неправильно закрытыми кавычками
"""

import re
import os
from pathlib import Path

def fix_logger_line(line):
    """Исправляет одну строку с AppLogger"""
    # Паттерн: AppLogger.shared.xxx("message", category: .xxx) что-то еще
    # Ищем случаи, где после category: .xxx) есть еще текст (не ; или })
    
    # Паттерн 1: category: .xxx) + текст (дублирование)
    pattern1 = r'(AppLogger\.shared\.\w+\("[^"]*",\s*category:\s*\.\w+\))\s*([^;\s}].*)'
    match = re.search(pattern1, line)
    if match:
        # Удаляем все после category: .xxx)
        return match.group(1)
    
    # Паттерн 2: category: .xxx)" (лишняя кавычка)
    pattern2 = r'(AppLogger\.shared\.\w+\("[^"]*",\s*category:\s*\.\w+\))"'
    match = re.search(pattern2, line)
    if match:
        return match.group(1)
    
    # Паттерн 3: ??", category: (неправильная обработка nil-coalescing)
    pattern3 = r'(\?\?\s*")[^"]*",\s*category:'
    if re.search(pattern3, line):
        # Это сложный случай - нужно восстановить из backup или исправить вручную
        # Пока просто пропускаем
        pass
    
    return line

def fix_file(filepath):
    """Исправляет файл"""
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            lines = f.readlines()
        
        modified = False
        new_lines = []
        
        for line in lines:
            if 'AppLogger.shared.' in line and 'category:' in line:
                fixed = fix_logger_line(line)
                if fixed != line:
                    new_lines.append(fixed.rstrip() + '\n')
                    modified = True
                    print(f"Fixed: {filepath}: {line.strip()[:80]} -> {fixed.strip()[:80]}")
                else:
                    new_lines.append(line)
            else:
                new_lines.append(line)
        
        if modified:
            with open(filepath, 'w', encoding='utf-8') as f:
                f.writelines(new_lines)
            return True
    except Exception as e:
        print(f"Error processing {filepath}: {e}")
    
    return False

def main():
    """Основная функция"""
    fixed_count = 0
    
    for swift_file in Path('Hohma').rglob('*.swift'):
        if '.backup' in str(swift_file):
            continue
        
        if fix_file(swift_file):
            fixed_count += 1
    
    print(f"\n✅ Исправлено файлов: {fixed_count}")

if __name__ == '__main__':
    main()

