# Agent Orchestrator Installer

Установщик набора субагентов и общих правил оркестрации для любого проекта.

Roadmap: [ROADMAP.md](./ROADMAP.md)

## Поддерживаемые ОС
- Windows (PowerShell)
- Linux
- macOS
- WSL

## Что это делает
Скрипт может работать в двух режимах:
1. Установка инфраструктуры агентов и правил
2. Анализ проекта и генерация обзорной документации

## Какие наборы агентов входят сейчас
- Core-оркестрация разработки:
  - Orchestrator, SC, UI-UX, UI-Test, CR, DOMAIN, VALIDATION, DOC
- Продуктовый контур (опциональный этап):
  - Product-Manager, Sprint-Prioritizer, Feedback-Synthesizer
- Growth + Marketing:
  - Growth-Hacker, Content-Creator, SEO, Social-Media
  - AI-Citation, Agentic-Search-Optimizer
  - App-Store, Video-Optimization, LinkedIn, Twitter/X, Reddit
- Paid media:
  - Tracking-Measurement, PPC, Paid-Social, Ad-Creative
  - Paid-Media-Auditor, Search-Query-Analyst, Programmatic-Display-Buyer
- Мультиязычная локализация:
  - Language-Translator-Agent (`EN/RU/HEB`)

## Полный флоу установки
1. Читает `project.config.json`
2. Проверяет `projectName` и `projectRoot`
3. Определяет `codexHome` (`<projectRoot>/.ai`, если не задан)
4. Копирует шаблоны:
   - `copilot-config/agents/*`
   - `shared-docs/dev/*`
   - `shared-docs/rules/*`
5. Рендерит `copilot-config/copilot-instructions.md` с токенами проекта
6. Рендерит policy-документы:
   - `shared-docs/rules/CONSTITUTION.md`
   - `shared-docs/rules/QUALITY-GATES.md`
7. Сразу спрашивает пользователя про второй шаг:
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
8. Генерирует машинно-читаемый summary:
   - `shared-docs/analysis-summary.json`
9. Если секция слишком большая, выносит детали в:
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

Дополнительные поля в `project.config.json` (опционально):
- `authProvider`
- `complianceRequirements`
- `a11yLevel`
- `language`
- `framework`
- `database`
- `hosting`
- `sharedTypesPath`

## Help по флагам
- Linux/macOS/WSL:
```bash
python3 scripts/install.py --help
```
- Windows PowerShell:
```powershell
Get-Help .\scripts\install.ps1 -Detailed
```

## Установка по URL репозитория (рекомендуемый bootstrap)

Основной режим (без локального git-клона installer-репозитория):
- скачивается входной bootstrap-скрипт
- архив installer скачивается в `<project>/.tmp/agent-installer`
- установка запускается из распакованной копии
- отдельный локальный git-репозиторий installer не создаётся

### Windows
```powershell
$tmp = Join-Path $env:TEMP "bootstrap-remote.ps1"
Invoke-WebRequest https://raw.githubusercontent.com/ale4ko69/agent-orchestrator-installer/main/scripts/bootstrap-remote.ps1 -OutFile $tmp
pwsh -NoProfile -ExecutionPolicy Bypass -File $tmp
```

### Linux/macOS/WSL
```bash
tmp="/tmp/bootstrap-remote.sh"
curl -fsSL https://raw.githubusercontent.com/ale4ko69/agent-orchestrator-installer/main/scripts/bootstrap-remote.sh -o "$tmp"
bash "$tmp"
```

Поведение bootstrap:
1. Проверяет, похожа ли текущая папка на корень проекта.
2. Спрашивает подтверждение использовать текущую папку.
3. Если пользователь отказался (или папка не проектная), просит путь к проекту.
4. Генерирует bootstrap-конфиг и запускает установщик.

Можно явно передать путь проекта:
- Windows: `pwsh -File $tmp -ProjectPath "D:\path\to\project"`
- Linux/macOS/WSL: `bash "$tmp" /path/to/project`

Опционально (классический локальный режим):
- можно клонировать installer-репозиторий и запускать `scripts/bootstrap.ps1` / `scripts/bootstrap.sh`

Интеграции `Gastown/Beads` сейчас отложены и запланированы как будущие opt-in профили (см. roadmap).

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
    rules/CONSTITUTION.md
    rules/QUALITY-GATES.md
    project-overview.md
    analysis-summary.json
    modules/*.md (опционально, если секции большие)
```
