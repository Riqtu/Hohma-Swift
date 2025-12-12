#!/usr/bin/env python3
"""
Скрипт для синхронизации SUPPORT_EMAIL из Info.plist в markdown файлы.

Использование:
    python3 sync_support_email.py [--dry-run]
"""

import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

# Файлы для обновления
MARKDOWN_FILES = [
    "TermsOfService.md",
    "PrivacyPolicy.md",
    "UserAgreement.md",
    "LEGAL_SETUP.md",
]

INFO_PLIST_PATH = "Hohma/Info.plist"


def extract_email_from_plist(plist_path: str) -> str:
    """Извлекает SUPPORT_EMAIL из Info.plist"""
    try:
        tree = ET.parse(plist_path)
        root = tree.getroot()
        
        # Info.plist имеет структуру <dict> с <key> и <string>
        # Ищем ключ SUPPORT_EMAIL
        current_key = None
        for elem in root.iter():
            if elem.tag == 'key' and elem.text == 'SUPPORT_EMAIL':
                current_key = 'SUPPORT_EMAIL'
            elif elem.tag == 'string' and current_key == 'SUPPORT_EMAIL':
                return elem.text
        
        raise ValueError("SUPPORT_EMAIL не найден в Info.plist")
    except Exception as e:
        print(f"❌ Ошибка чтения {plist_path}: {e}")
        sys.exit(1)


def update_markdown_file(file_path: str, new_email: str, dry_run: bool = False) -> bool:
    """Обновляет email в markdown файле"""
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()
    except Exception as e:
        print(f"❌ Ошибка чтения {file_path}: {e}")
        return False
    
    # Паттерн для поиска email в различных форматах
    # Используем простую замену всего email адреса
    original_content = content
    
    # Заменяем все вхождения email
    if 'xxx-zet@mail.ru' in content:
        # Если новый email такой же, как старый, файл не изменится
        # Но это нормально - значит email уже синхронизирован
        if new_email == 'xxx-zet@mail.ru':
            print(f"  ℹ️ {file_path} уже содержит правильный email")
            return False
        content = content.replace('xxx-zet@mail.ru', new_email)
    else:
        # Пробуем найти через regex с различными форматами
        patterns = [
            (r'\*\*Email:\*\*\s*xxx-zet@mail\.ru', f'**Email:** {new_email}'),
            (r'- Email:\s*xxx-zet@mail\.ru', f'- Email: {new_email}'),
            (r'Email:\s*xxx-zet@mail\.ru', f'Email: {new_email}'),
        ]
        for pattern, replacement in patterns:
            content = re.sub(pattern, replacement, content)
    
    if content == original_content:
        print(f"  ⚠️ Email не найден в {file_path}")
        return False
    
    if dry_run:
        print(f"  ✓ Будет обновлен {file_path}")
        print(f"    → {new_email}")
        return True
    
    try:
        with open(file_path, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"  ✅ Обновлен {file_path}")
        return True
    except Exception as e:
        print(f"  ❌ Ошибка записи {file_path}: {e}")
        return False


def main():
    dry_run = '--dry-run' in sys.argv
    
    if dry_run:
        print("🔍 Режим предварительного просмотра (dry-run)\n")
    
    # Извлекаем email из Info.plist
    print(f"📖 Чтение {INFO_PLIST_PATH}...")
    email = extract_email_from_plist(INFO_PLIST_PATH)
    print(f"  ✓ Найден email: {email}\n")
    
    # Обновляем markdown файлы
    print("📝 Обновление markdown файлов...")
    updated_count = 0
    for md_file in MARKDOWN_FILES:
        if Path(md_file).exists():
            if update_markdown_file(md_file, email, dry_run):
                updated_count += 1
        else:
            print(f"  ⚠️ Файл не найден: {md_file}")
    
    print(f"\n✅ Обработано файлов: {updated_count}/{len(MARKDOWN_FILES)}")
    
    if not dry_run:
        print("\n💡 Совет: Запустите этот скрипт после изменения SUPPORT_EMAIL в Info.plist")


if __name__ == '__main__':
    main()

