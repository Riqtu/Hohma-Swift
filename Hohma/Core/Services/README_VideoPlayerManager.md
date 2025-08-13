# VideoPlayerManager - Улучшенная система управления видео

## Обзор изменений

Система управления видео была полностью переработана для решения следующих проблем:

### Проблемы, которые были исправлены:

1. **Проблемы с жизненным циклом**

   - Видео не запускалось при переходе между экранами
   - Видео останавливалось при переоткрытии приложения
   - Неправильная обработка состояний приложения

2. **Проблемы с кэшированием**

   - Плееры не переиспользовались эффективно
   - Утечки памяти из-за неправильной очистки observers
   - Отсутствие автоматической очистки неиспользуемых плееров

3. **Проблемы с загрузкой**

   - Видео долго загружались по сравнению с веб-версией
   - Отсутствие предварительной загрузки
   - Нет оптимизации для быстрого старта

4. **Проблемы с синхронизацией**
   - Неправильная синхронизация между разными компонентами
   - Отсутствие централизованного управления

## Ключевые улучшения

### 1. Улучшенное кэширование

```swift
private class CachedPlayer {
    let player: AVPlayer
    var isReady: Bool = false
    var isLoading: Bool = false
    var lastUsed: Date = Date()
    var observers: [NSObjectProtocol] = []
    private var cancellables = Set<AnyCancellable>()
}
```

- **Автоматическое отслеживание состояния**: Каждый плеер отслеживает свое состояние готовности
- **Временные метки**: Отслеживание последнего использования для очистки
- **Правильная очистка observers**: Использование Combine для автоматической очистки

### 2. Умная очистка кэша

```swift
private func clearUnusedCache() {
    let now = Date()
    let unusedThreshold: TimeInterval = 300 // 5 минут

    let keysToRemove = cache.compactMap { key, cachedPlayer in
        now.timeIntervalSince(cachedPlayer.lastUsed) > unusedThreshold ? key : nil
    }

    for key in keysToRemove {
        removePlayer(for: key)
    }
}
```

- **Автоматическая очистка**: Удаление неиспользуемых плееров каждые 5 минут
- **Ограничение размера кэша**: Максимум 5 плееров в кэше
- **Обработка предупреждений о памяти**: Автоматическая очистка при нехватке памяти

### 3. Предварительная загрузка

```swift
func preloadVideo(resourceName: String, resourceExtension: String = "mp4") {
    _ = player(resourceName: resourceName, resourceExtension: resourceExtension)
}

func preloadVideo(url: URL) {
    _ = player(url: url)
}
```

- **Предварительная загрузка при запуске**: Часто используемые видео загружаются заранее
- **Быстрый доступ**: Кэшированные плееры готовы к немедленному использованию

### 4. Улучшенное управление жизненным циклом

```swift
private func setupAppLifecycleObservers() {
    #if os(iOS)
    let willResignObserver = NotificationCenter.default.addObserver(
        forName: UIApplication.willResignActiveNotification,
        object: nil,
        queue: .main
    ) { [weak self] _ in
        self?.pauseAllPlayers()
    }

    let didBecomeObserver = NotificationCenter.default.addObserver(
        forName: UIApplication.didBecomeActiveNotification,
        object: nil,
        queue: .main
    ) { [weak self] _ in
        self?.resumeAllPlayers()
    }

    let didEnterBackgroundObserver = NotificationCenter.default.addObserver(
        forName: UIApplication.didEnterBackgroundNotification,
        object: nil,
        queue: .main
    ) { [weak self] _ in
        self?.pauseAllPlayers()
    }
    #endif
}
```

- **Полная поддержка жизненного цикла**: Обработка всех состояний приложения
- **Автоматическая пауза/возобновление**: Видео корректно останавливается и запускается

### 5. Оптимизация производительности

```swift
private func createPlayer(for url: URL, key: String) -> AVPlayer {
    let player = AVPlayer(url: url)
    player.isMuted = true
    player.actionAtItemEnd = .none

    // Настройки для быстрой загрузки
    player.automaticallyWaitsToMinimizeStalling = false

    // Создаем cached player
    let cachedPlayer = CachedPlayer(player: player)
    cache[key] = cachedPlayer

    // Начинаем воспроизведение
    player.play()

    return player
}
```

- **Быстрая загрузка**: `automaticallyWaitsToMinimizeStalling = false`
- **Автоматическое воспроизведение**: Плеер запускается сразу после создания

## Использование в компонентах

### AppBackground

```swift
private func setupVideoBackground() {
    // Предварительно загружаем видео
    videoManager.preloadVideo(resourceName: videoName)

    // Получаем плеер
    backgroundPlayer = videoManager.player(resourceName: videoName)

    // Настраиваем observer для готовности
    if let player = backgroundPlayer {
        setupPlayerObserver(player)
    }
}
```

### CardView

```swift
private func setupVideoIfNeeded() {
    // Если уже есть готовый плеер, используем его
    if let player = player {
        setupPlayerObserver(player)
        return
    }

    // Если есть имя видео, загружаем его
    if let videoName = videoName, !videoName.isEmpty {
        videoPlayer = videoManager.player(resourceName: videoName)
        if let player = videoPlayer {
            setupPlayerObserver(player)
        }
    }
}
```

### FortuneWheelViewModel

```swift
func setupVideoBackground() {
    guard let videoURL = URL(string: wheelState.backVideo) else { return }

    // Используем VideoPlayerManager для лучшего управления
    player = VideoPlayerManager.shared.player(url: videoURL)

    // Настраиваем observer для готовности
    if let player = player {
        setupPlayerObserver(player)
    }
}
```

## Преимущества новой системы

1. **Производительность**

   - Быстрая загрузка видео благодаря предварительной загрузке
   - Эффективное кэширование и переиспользование плееров
   - Оптимизированные настройки для быстрого старта

2. **Надежность**

   - Правильная обработка жизненного цикла приложения
   - Автоматическая очистка ресурсов
   - Отсутствие утечек памяти

3. **Удобство использования**

   - Централизованное управление всеми видео
   - Автоматическая обработка состояний
   - Простой API для компонентов

4. **Масштабируемость**
   - Легко добавлять новые видео
   - Гибкая система кэширования
   - Поддержка как локальных, так и удаленных видео

## Рекомендации по использованию

1. **Всегда используйте VideoPlayerManager** для создания плееров
2. **Предварительно загружайте** часто используемые видео
3. **Настраивайте observers** для отслеживания готовности плееров
4. **Правильно очищайте ресурсы** при исчезновении компонентов
5. **Используйте состояния готовности** для показа/скрытия видео

## Миграция с старой системы

1. Замените прямые вызовы `AVPlayer(url:)` на `VideoPlayerManager.shared.player(url:)`
2. Добавьте отслеживание состояния готовности в компоненты
3. Используйте предварительную загрузку для часто используемых видео
4. Обновите обработку жизненного цикла в компонентах
