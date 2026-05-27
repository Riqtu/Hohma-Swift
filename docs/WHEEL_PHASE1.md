# Fortune Wheel — изменения безопасности и iOS (фаза 1)

Подробности на бэкенде см. также в `/Users/riqtu/projects/hohma-next` — `src/server/services/wheelAccess.ts`.

## Backend (`hohma-next`)

- **`wheelList.create`** только для авторизованных (`tProtected`), владелец из сессии.
- **`wheelList.update` / `delete`** — только автор колеса.
- **`wheelList.getById`** — для приватных колёс: автор, ставка пользователя или подписка на автора.
- **Секторы**: доступ как у чтения колеса; в приватном колесе секторы добавляет только автор; `userId` сектора всегда из сессии.
- **Ставки**: ставки недоступны для завершённых/неактивных колёс; **`payoutBets`** — только автор колеса.

## iOS (`Hohma`)

- Видео темы с относительным путём строится от `DOMAIN` из Info.plist; без видео экран игры всё равно открывается.
- Перед повторной подпиской снимаются Socket.IO-хендлеры колеса (`removeWheelRoomEventHandlers`).
- Таймеры мониторинга колеса инвалидируются в `cleanup()`; `roomUsers` наблюдается через токен NotificationCenter.
- **`AppConstants.fortuneWheelAutomaticPayoutEnabled`**: пока `false`, клиент не дергает `bet.payoutBets`; на сервере выплату всё равно может инициировать только автор.

## Фаза 2 — серверный спин (`hohma-next-server`)

- Клиент шлёт **`wheel:spin:request`** `(roomId, { rotation, speed, sectorCount, clientId })`.
- Сервер (`wheelSpinAuthority.ts`) выбирает **`winningIndex`** и **`rotation`**, рассылает **`wheel:spin`** всем в комнате (`generatedByServer: true`, `spinId`).
- iOS и web **не** считают исход локально; анимация и `handleSpinResult` — только после события с сервера.
- Legacy **`wheel:spin`** (relay) оставлен для старых клиентов.
