# Окружения iOS (dev / prod)

## Быстрый старт

```bash
cp Config.local.xcconfig.example Config.local.xcconfig
# KINOPOISK_API_KEY

# Только для Hohma Debug на физическом iPhone:
cp Config.local.dev.xcconfig.example Config.local.dev.xcconfig
```

| Схема Xcode     | Конфигурация | API / WS                                           |
| --------------- | ------------ | -------------------------------------------------- |
| **Hohma Debug** | Debug        | localhost или `Config.local.dev.xcconfig` (IP Mac) |
| **Hohma**       | Release      | `hohma.su` — dev URL из local **не** подмешиваются |

## Файлы

- `Debug.xcconfig` — dev по умолчанию (`127.0.0.1`)
- `Release.xcconfig` — production
- `Config.local.xcconfig` — **только секреты** (обе схемы)
- `Config.local.dev.xcconfig` — **только Hohma Debug**: IP Mac для iPhone

## iPhone в Wi‑Fi (только Hohma Debug)

IP Mac — в `Config.local.dev.xcconfig`, не в `Config.local.xcconfig`.

Сервер на Mac должен слушать `0.0.0.0`.

## Версия приложения

Меняется в Xcode: **Target Hohma → General → Version / Build**.
