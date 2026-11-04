# Yarus — складской учёт

Yarus — учебное Rails-приложение для учёта товаров, складов, текущих остатков и истории операций прихода/расхода.

## Технологии

- Ruby **4.0.9**
- RubyGems **4.0.20**
- Ruby on Rails **8.1.4**
- Bundler **4.0.20**
- PostgreSQL **18.6** (поддерживается PostgreSQL 10 и новее драйвером `pg`)
- ERB и обычная MVC-архитектура Rails
- Minitest

В проекте сохранены `config.load_defaults 7.1` и версии миграций `ActiveRecord::Migration[7.1]`. Rails 8.1 сохраняет настройки и классы совместимости предыдущих версий; переход на новые defaults здесь не выполняется автоматически.

## Что реализовано

- модели `User`, `Product`, `Warehouse`, `InventoryBalance`, `StockMovement`;
- пять миграций с внешними ключами, индексами и ограничениями PostgreSQL;
- Repository Pattern в `app/repositories/`;
- сервис `StockMovements::Create` для атомарного прихода и расхода;
- MVC-контроллеры и маршруты для товаров, складов, остатков и истории операций;
- поиск, фильтрация и пагинация;
- регрессионные Minitest-тесты для репозиториев и складского сервиса.

`User` — базовая модель с email, `encrypted_password`, полями восстановления пароля и ролью. Полноценные регистрация, вход/выход и политики доступа в эту backend-часть не включены; Devise и Pundit не подключены.

## Быстрый запуск на Windows

1. Установите Ruby 4.0.9 (64-bit UCRT-сборка), RubyGems 4.0.20 и PostgreSQL 18.6. Убедитесь, что `ruby` и `gem` доступны из PowerShell через `PATH`, а служба PostgreSQL запущена. `psql` полезен для ручной проверки, но проверочный скрипт подключается через Ruby-драйвер `pg`.

2. Распакуйте архив и откройте PowerShell в папке `Yarus-main`.

3. При необходимости скопируйте `.env.example` в `.env` и укажите свои host, port и username PostgreSQL. Пароль в `.env` не записывайте: скрипт запросит его скрытым вводом, если `YARUS_DB_PASSWORD` или `PGPASSWORD` не заданы.

4. Выполните одну команду:
   
   ```powershell
   .\scripts\verify_backend.ps1
   ```
   
   Если Windows запрещает запуск локальных скриптов, используйте только для текущего окна PowerShell:
   
   ```powershell
   Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
   .\scripts\verify_backend.ps1
   ```

Скрипт проверит версии Ruby/RubyGems/Bundler/Rails, установит зависимости, проверит Zeitwerk и соединение именно с PostgreSQL 18.6, подготовит development- и test-базы, покажет статус миграций и запустит Minitest. При первом запуске он автоматически пересоберёт `Gemfile.lock` целевым Bundler 4.0.20; последующие запуски используют уже зафиксированные зависимости. Скрипт не меняет пароль PostgreSQL и не создаёт/меняет роли PostgreSQL. Для создания баз у указанной роли должно быть соответствующее право.

## Параметры PostgreSQL

`config/database.yml` читает следующие переменные окружения:

| Переменная                      | Значение по умолчанию                             |
| ------------------------------- | ------------------------------------------------- |
| `YARUS_DB_HOST`                 | `localhost`                                       |
| `YARUS_DB_PORT`                 | `5432`                                            |
| `YARUS_DB_USERNAME`             | `postgres` (если не задан `PGUSER`)               |
| `YARUS_DB_PASSWORD`             | не задан (альтернатива — `PGPASSWORD`)            |
| `YARUS_DB_DEVELOPMENT`          | `yarus_development`                               |
| `YARUS_DB_TEST`                 | `yarus_test`                                      |
| `YARUS_DB_PRODUCTION`           | `yarus_production`                                |
| `YARUS_DB_MAINTENANCE_DATABASE` | `postgres` (служебная БД для проверки соединения) |
| `YARUS_DB_CONNECT_TIMEOUT`      | `5` секунд                                        |

Пример задания параметров в текущем PowerShell-сеансе:

```powershell
$env:YARUS_DB_HOST = "localhost"
$env:YARUS_DB_PORT = "5432"
$env:YARUS_DB_USERNAME = "postgres"
# Пароль лучше ввести по запросу verify_backend.ps1.
```

Скрипт читает необязательный локальный `.env` файл. `.env` игнорируется Git; `.env.example` содержит только пример без секретов.

## Полезные команды после успешной проверки

```powershell
ruby .\bin\rails server
ruby .\bin\rails routes
ruby .\bin\rails test
ruby .\bin\rails db:migrate:status
```

## Архитектура и бизнес-правила

Подробное описание моделей, репозиториев, транзакции и ручных сценариев находится в [`BACKEND_IMPLEMENTATION.md`](BACKEND_IMPLEMENTATION.md).

## Важные ограничения текущей версии

- Интерфейс складских страниц ещё не является частью этой backend-реализации; существующая стартовая страница сохранена.
- Для создания складского движения нужен сохранённый пользователь. Контроллер получает текущего пользователя через `current_user`, если этот метод предоставлен подключённым механизмом аутентификации. Сам механизм аутентификации здесь не настраивается.
- История `StockMovement` не имеет маршрутов редактирования и удаления и защищена callbacks модели от обычных `update`/`destroy`.
- Исправление ошибочной операции выполняется новой обратной складской операцией, а не изменением истории.
