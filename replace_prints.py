#!/usr/bin/env python3
"""
Скрипт для массовой замены print() на AppLogger в Swift файлах
Использование: python3 replace_prints.py [--dry-run] [--file path/to/file.swift]
"""

import os
import re
import sys
import argparse
from pathlib import Path
from typing import List, Tuple, Optional

# Маппинг эмодзи на уровни логирования
EMOJI_TO_LEVEL = {
    "❌": "error",
    "⚠️": "warning",
    "✅": "info",
    "🔍": "debug",
    "📦": "info",
    "📥": "debug",
    "📤": "debug",
    "🔌": "debug",
    "🔐": "debug",
    "💬": "debug",
    "🏁": "debug",
    "🎲": "debug",
    "🎮": "debug",
    "🔄": "debug",
    "🔗": "debug",
    "🏠": "debug",
    "📱": "debug",
    "▶️": "debug",
    "💥": "fault",
}

# Определение категории по пути файла
def get_category_from_path(file_path: str) -> str:
    """Определяет категорию логирования на основе пути к файлу"""
    path_lower = file_path.lower()
    
    if "network" in path_lower or "trpc" in path_lower:
        return ".network"
    elif "auth" in path_lower:
        return ".auth"
    elif "socket" in path_lower:
        return ".socket"
    elif "cache" in path_lower or "imagecache" in path_lower:
        return ".cache"
    elif "keychain" in path_lower:
        return ".keychain"
    elif "viewmodel" in path_lower or "view" in path_lower:
        return ".ui"
    else:
        return ".general"

# Определение уровня логирования по содержимому
def get_log_level(message: str) -> str:
    """Определяет уровень логирования на основе сообщения"""
    message_lower = message.lower()
    
    # Проверяем эмодзи
    for emoji, level in EMOJI_TO_LEVEL.items():
        if emoji in message:
            return level
    
    # Проверяем ключевые слова
    if any(word in message_lower for word in ["error", "failed", "ошибка", "не удалось"]):
        return "error"
    elif any(word in message_lower for word in ["warn", "warning", "предупреждение"]):
        return "warning"
    elif any(word in message_lower for word in ["info", "информация", "успешно", "success"]):
        return "info"
    else:
        return "debug"

# Извлечение сообщения из print()
def extract_message(print_line: str) -> Optional[str]:
    """Извлекает сообщение из print() с учетом Swift интерполяции"""
    # Убираем начальные пробелы
    line = print_line.strip()
    if not 'print(' in line:
        return None
    
    # Находим начало print(
    start_idx = line.find('print(')
    if start_idx == -1:
        return None
    
    # Находим открывающую кавычку после print(
    quote_start = line.find('"', start_idx + 6)
    if quote_start == -1:
        return None
    
    # Находим закрывающую кавычку, учитывая интерполяцию \(...)
    # Нужно найти кавычку, которая закрывает строку, а не находится внутри \(...)
    quote_end = quote_start + 1
    paren_depth = 0  # Глубина вложенности скобок в интерполяции
    
    while quote_end < len(line):
        char = line[quote_end]
        
        # Проверяем начало интерполяции \(
        if quote_end < len(line) - 1 and line[quote_end:quote_end+2] == '\\(':
            paren_depth += 1
            quote_end += 2
            continue
        
        # Проверяем закрывающую скобку интерполяции
        if char == ')' and paren_depth > 0:
            paren_depth -= 1
            quote_end += 1
            continue
        
        # Если нашли кавычку и мы не внутри интерполяции
        if char == '"' and paren_depth == 0 and line[quote_end - 1] != '\\':
            break
        
        quote_end += 1
    else:
        return None
    
    message = line[quote_start + 1:quote_end]
    return message

# Замена print() на AppLogger
def replace_print(print_line: str, file_path: str) -> Optional[str]:
    """Заменяет print() на соответствующий вызов AppLogger"""
    # Пропускаем print в AppLogger.swift (это нормально)
    if "AppLogger.swift" in file_path:
        return None
    
    # Извлекаем сообщение
    message = extract_message(print_line)
    if not message:
        return None
    
    # Определяем уровень и категорию
    level = get_log_level(message)
    category = get_category_from_path(file_path)
    
    # Убираем эмодзи из сообщения (они уже в уровне)
    clean_message = message
    for emoji in EMOJI_TO_LEVEL.keys():
        clean_message = clean_message.replace(emoji, "").strip()
    
    # Убираем префиксы типа "ChatViewModel: " или "Service: "
    clean_message = re.sub(r'^[A-Za-z]+[A-Za-z0-9]*:\s*', '', clean_message)
    clean_message = clean_message.strip()
    
    # Формируем замену
    if level == "error":
        # Для ошибок может быть error: Error?
        replacement = f'AppLogger.shared.error("{clean_message}", category: {category})'
    elif level == "fault":
        replacement = f'AppLogger.shared.fault("{clean_message}", category: {category})'
    elif level == "warning":
        replacement = f'AppLogger.shared.warning("{clean_message}", category: {category})'
    elif level == "info":
        replacement = f'AppLogger.shared.info("{clean_message}", category: {category})'
    else:  # debug
        replacement = f'AppLogger.shared.debug("{clean_message}", category: {category})'
    
    # Заменяем print(...) на AppLogger вызов
    # Сохраняем отступы
    indent_match = re.match(r'^(\s*)', print_line)
    indent = indent_match.group(1) if indent_match else ""
    
    # Находим начало print(
    start_idx = print_line.find('print(')
    if start_idx == -1:
        return None
    
    # Находим открывающую кавычку
    quote_start = print_line.find('"', start_idx + 6)
    if quote_start == -1:
        return None
    
    # Находим закрывающую кавычку (используем ту же логику что и в extract_message)
    quote_end = quote_start + 1
    paren_depth = 0
    
    while quote_end < len(print_line):
        if quote_end < len(print_line) - 1 and print_line[quote_end:quote_end+2] == '\\(':
            paren_depth += 1
            quote_end += 2
            continue
        if print_line[quote_end] == ')' and paren_depth > 0:
            paren_depth -= 1
            quote_end += 1
            continue
        if print_line[quote_end] == '"' and paren_depth == 0 and print_line[quote_end - 1] != '\\':
            break
        quote_end += 1
    else:
        return None
    
    # Находим закрывающую скобку print()
    close_paren = print_line.find(')', quote_end + 1)
    if close_paren == -1:
        return None
    
    # Формируем результат: отступ + замена + остаток строки после print()
    result = print_line[:start_idx] + replacement + print_line[close_paren + 1:]
    
    return result

# Обработка файла
def process_file(file_path: str, dry_run: bool = False) -> Tuple[int, int]:
    """Обрабатывает один файл, возвращает (заменено, ошибок)"""
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            lines = f.readlines()
    except Exception as e:
        print(f"❌ Ошибка чтения {file_path}: {e}")
        return 0, 1
    
    new_lines = []
    replaced_count = 0
    error_count = 0
    
    for i, line in enumerate(lines):
        # Ищем print()
        if 'print(' in line and 'AppLogger' not in line:
            try:
                replacement = replace_print(line, file_path)
                if replacement and replacement != line:
                    new_lines.append(replacement)
                    replaced_count += 1
                    if dry_run:
                        print(f"  ✓ Строка {i+1}: {line.strip()[:60]}...")
                        print(f"    → {replacement.strip()[:60]}...")
                else:
                    new_lines.append(line)
            except Exception as e:
                print(f"  ⚠️ Ошибка в строке {i+1}: {e}")
                new_lines.append(line)
                error_count += 1
        else:
            new_lines.append(line)
    
    # Сохраняем файл
    if replaced_count > 0 and not dry_run:
        try:
            # Создаем backup
            backup_path = file_path + '.backup'
            with open(backup_path, 'w', encoding='utf-8') as f:
                f.writelines(lines)
            
            with open(file_path, 'w', encoding='utf-8') as f:
                f.writelines(new_lines)
            
            print(f"  ✅ Заменено {replaced_count} print(), backup: {backup_path}")
        except Exception as e:
            print(f"  ❌ Ошибка записи {file_path}: {e}")
            error_count += 1
    
    return replaced_count, error_count

# Поиск Swift файлов
def find_swift_files(root_dir: str, exclude_dirs: List[str] = None) -> List[str]:
    """Находит все Swift файлы в директории"""
    if exclude_dirs is None:
        exclude_dirs = ['node_modules', '.git', 'build', 'DerivedData', '.swiftpm']
    
    swift_files = []
    for root, dirs, files in os.walk(root_dir):
        # Исключаем директории
        dirs[:] = [d for d in dirs if d not in exclude_dirs]
        
        for file in files:
            if file.endswith('.swift'):
                file_path = os.path.join(root, file)
                # Пропускаем backup файлы
                if not file_path.endswith('.backup'):
                    swift_files.append(file_path)
    
    return sorted(swift_files)

# Главная функция
def main():
    parser = argparse.ArgumentParser(description='Замена print() на AppLogger в Swift файлах')
    parser.add_argument('--dry-run', action='store_true', help='Только показать что будет заменено, не изменять файлы')
    parser.add_argument('--file', type=str, help='Обработать только указанный файл')
    parser.add_argument('--dir', type=str, default='Hohma', help='Директория для поиска (по умолчанию: Hohma)')
    
    args = parser.parse_args()
    
    print("🔍 Поиск Swift файлов с print()...")
    
    if args.file:
        files = [args.file] if os.path.exists(args.file) else []
    else:
        files = find_swift_files(args.dir)
    
    # Фильтруем файлы с print()
    files_with_print = []
    for file_path in files:
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                content = f.read()
                if 'print(' in content and 'AppLogger' not in content:
                    files_with_print.append(file_path)
        except:
            pass
    
    print(f"📋 Найдено {len(files_with_print)} файлов с print()")
    
    if args.dry_run:
        print("\n🔍 DRY RUN - файлы не будут изменены\n")
    
    total_replaced = 0
    total_errors = 0
    
    for file_path in files_with_print:
        print(f"\n📄 {file_path}")
        replaced, errors = process_file(file_path, dry_run=args.dry_run)
        total_replaced += replaced
        total_errors += errors
    
    print(f"\n{'='*60}")
    print(f"✅ Всего заменено: {total_replaced} print()")
    if total_errors > 0:
        print(f"⚠️ Ошибок: {total_errors}")
    print(f"{'='*60}")
    
    if args.dry_run:
        print("\n💡 Запустите без --dry-run для применения изменений")

if __name__ == '__main__':
    main()

