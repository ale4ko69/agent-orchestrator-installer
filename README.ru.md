# Agent Orchestrator Installer

Установщик набора субагентов и общих правил оркестрации для любого проекта.

## Поддерживаемые ОС
- Windows (PowerShell)
- Linux
- macOS
- WSL

## Что это делает
Скрипт может работать в двух режимах:
1. Установка инфраструктуры агентов и правил
2. Анализ проекта и генерация обзорной документации

## Полный флоу установки
1. Читает `project.config.json`
2. Проверяет `projectName` и `projectRoot`
3. Определяет `codexHome` (`<projectRoot>/.ai`, если не задан)
4. Копирует шаблоны:
   - `copilot-config/agents/*`
   - `shared-docs/dev/*`
   - `shared-docs/rules/*`
5. Рендерит `copilot-config/copilot-instructions.md` с токенами проекта
6. Сразу спрашивает пользователя про второй шаг:
   - запустить обзорный анализ проекта прямо сейчас
   - при ответе `y/yes` сразу выполняет анализ и генерирует `project-overview.md`

## Полный флоу анализа
При флаге анализа скрипт:
1. Сканирует структуру репозитория (с исключениями: `.git`, `node_modules`, `dist`, `build`, `.venv`, и т.д.)
2. Ищет манифесты/entry points (`package.json`, `pyproject.toml`, `go.mod`, `Cargo.toml`, `Dockerfile`, `docker-compose*`, `Makefile`, CI workflows)
3. Ищет папки и файлы `.md` по всему проекту как источники существующей документации
4. Выделяет модульные зоны:
   - Docs Intake
   - UI
   - Server/API
   - Services/Workers
   - Infra/CI
5. Пытается извлечь команды запуска/сборки/тестов
6. Формирует риски, unknowns и suggested agent profile
7. Генерирует один главный файл:
   - `shared-docs/project-overview.md`
8. Если секция слишком большая, выносит детали в:
   - `shared-docs/modules/docs.md`
   - `shared-docs/modules/ui.md`
   - `shared-docs/modules/server.md`
   - `shared-docs/modules/services.md`
   - `shared-docs/modules/infra.md`
   и оставляет ссылки в главном файле

## Новый проект (пустой репозиторий)
Если проект новый и кода почти нет:
- `project-overview.md` всё равно создаётся
- добавляется блок `New Project Bootstrap Notes`
- unknowns и риски помечаются явно
- после первого scaffold-коммита можно перезапустить анализ

## Режимы и флаги
- `-DryRun / --dry-run`: показать изменения без записи файлов
- `-UpdateOnly / --update-only`: обновлять только существующие файлы
- `-AnalyzeProject / --analyze-project`: запустить анализ и генерацию обзора
- `-AnalyzeOnly / --analyze-only`: только анализ, без установки шаблонов
- `-ModuleSplitThreshold / --module-split-threshold`: порог вынесения секции в отдельный модульный файл (default: 12)
- `-AnalyzeProfile / --analyze-profile`: профиль анализа `auto|node|python|go|java|generic` (default: `auto`)
- `-NoSecondStepPrompt / --no-second-step-prompt`: не спрашивать про второй шаг после установки

## Help по флагам
- Linux/macOS/WSL:
```bash
python3 scripts/install.py --help
```
- Windows PowerShell:
```powershell
Get-Help .\scripts\install.ps1 -Detailed
```

## Запуск
### Windows
```powershell
pwsh ./scripts/install.ps1 -ConfigPath ./project.config.json
pwsh ./scripts/install.ps1 -ConfigPath ./project.config.json -AnalyzeProject
pwsh ./scripts/install.ps1 -ConfigPath ./project.config.json -AnalyzeProject -AnalyzeOnly
pwsh ./scripts/install.ps1 -ConfigPath ./project.config.json -AnalyzeProject -ModuleSplitThreshold 8
pwsh ./scripts/install.ps1 -ConfigPath ./project.config.json -AnalyzeProject -AnalyzeProfile node
pwsh ./scripts/install.ps1 -ConfigPath ./project.config.json -DryRun -AnalyzeProject
```

PowerShell может быть ограничен Execution Policy. Без админ-прав используйте:
```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File .\scripts\install.ps1 -ConfigPath .\project.config.json -AnalyzeProject
```

Или вообще без PowerShell (через `cmd` + Python):
```bat
.\scripts\install.cmd .\project.config.json --analyze-project
```

### Linux/macOS/WSL
```bash
bash ./scripts/install.sh ./project.config.json
bash ./scripts/install.sh ./project.config.json --analyze-project
bash ./scripts/install.sh ./project.config.json --analyze-project --analyze-only
bash ./scripts/install.sh ./project.config.json --analyze-project --module-split-threshold 8
bash ./scripts/install.sh ./project.config.json --analyze-project --analyze-profile python
bash ./scripts/install.sh ./project.config.json --dry-run --analyze-project
```

## Нужны ли права администратора?
Обычно не нужны. Скрипты:
- читают файлы проекта
- создают/обновляют файлы только внутри целевого `projectRoot/.ai` (или `codexHome`)
- не ставят системные пакеты и не пишут в системные директории

Админ-доступ может понадобиться только если сам проект лежит в защищённой папке ОС.

## Что создаётся в целевом проекте
```text
<project>/.ai/
  copilot-config/
    copilot-instructions.md
    agents/*.agent.md
  shared-docs/
    dev/*.md
    rules/*.md
    project-overview.md
    modules/*.md (опционально, если секции большие)
```

