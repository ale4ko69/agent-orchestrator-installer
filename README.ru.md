# Agent Orchestrator Installer

Английская версия: [README.md](./README.md)

`agent-orchestrator-installer` устанавливает в существующий проект готовую инфраструктуру для работы с ИИ-агентами. Он может сгенерировать инструкции для Copilot, входные файлы для Claude Code, проектные и глобальные материалы для Codex, общие правила проекта, дополнительные пакеты и обзорный анализ кодовой базы.

Установщик рассчитан на повторяемые обновления: цели, переданные через CLI, переопределяют цели из конфигурации; `diff` работает как строгий режим без записи; корневые instruction-файлы обновляются через управляемые блоки; файлы, убираемые миграцией, сначала попадают в `.trash/`, а не удаляются сразу.

## Поддерживаемые Платформы

- Windows PowerShell (`pwsh` предпочтителен, Windows PowerShell тоже поддерживается)
- Linux, macOS и WSL через `scripts/install.sh` / Python
- запасной запуск через Python: `scripts/install.py` или `scripts/install.cmd`

## Что Устанавливается

Цели установки можно включать вместе или по отдельности:

- `copilot`
  - `.ai/copilot-config/copilot-instructions.md`
  - `.ai/copilot-config/agents/*.agent.md`
  - `.ai/shared-docs/**`
- `claude`
  - `CLAUDE.md`
- `codex`
  - `AGENTS.md`
  - `<project>/.codex/agents/*.toml`
  - `<project>/.codex/project-context/**`
  - `<user-codex-home>/skills/projects-*`

Если `installTargets` не задан и через CLI не передано переопределение, устанавливаются все три цели.

## Быстрый Старт

Из локальной копии этого installer:

```powershell
pwsh ./scripts/install.ps1 -ConfigPath ./project.config.json -AnalyzeProject
```

Через Python:

```powershell
py -3 ./scripts/install.py ./project.config.json --analyze-project
```

Предпросмотр без записи:

```powershell
pwsh ./scripts/install.ps1 -ConfigPath ./project.config.json -Diff -InstallTargets codex
py -3 ./scripts/install.py ./project.config.json --diff --install-targets codex
```

Обновить только Codex-слой:

```powershell
pwsh ./scripts/install.ps1 -ConfigPath ./project.config.json -InstallTargets codex -UpdateOnly -NoSecondStepPrompt
```

## Remote Bootstrap

Используй этот режим, если не хочешь клонировать репозиторий установщика внутрь целевого проекта.

### Windows

```powershell
$tmp = Join-Path $env:TEMP "bootstrap-remote.ps1"
Invoke-WebRequest https://raw.githubusercontent.com/ale4ko69/agent-orchestrator-installer/main/scripts/bootstrap-remote.ps1 -OutFile $tmp
$ps = if (Get-Command pwsh -ErrorAction SilentlyContinue) { "pwsh" } else { "powershell" }
& $ps -NoProfile -ExecutionPolicy Bypass -File $tmp
```

### Linux/macOS/WSL

```bash
tmp="/tmp/bootstrap-remote.sh"
curl -fsSL https://raw.githubusercontent.com/ale4ko69/agent-orchestrator-installer/main/scripts/bootstrap-remote.sh -o "$tmp"
bash "$tmp"
```

Удалённый bootstrap хранит кэш установщика в `<project>/.tmp/agent-installer`. Папки runtime и cache исключаются из анализа проекта и не считаются источниками переиспользуемых шаблонов.

## Конфигурация

Минимальный config:

```json
{
  "projectName": "My Project",
  "projectRoot": "D:/path/to/project",
  "codexHome": "D:/path/to/project/.ai",
  "projectCodexDir": "D:/path/to/project/.codex",
  "userCodexHome": "C:/Users/<user>/.codex",
  "installTargets": ["copilot", "claude", "codex"],
  "installCodexCli": false
}
```

Частые дополнительные поля:

- `enabledPacks`: массив или строка через запятую.
- `knowledge`: настройки локальной wiki знаний проекта; корень по умолчанию `.ai/knowledge`.
- `adminUiBase`: `admincore`, `custom` или `none`; по умолчанию `admincore`.
- `adminUiMode`: `canonical` или `legacy`; по умолчанию `canonical` в Python/shell точках входа.
- `adminUiCanonicalDir`: папка с `component-examples.json` и `css-report.json`; Python/shell точки входа используют её для canonical-импорта материалов Admin UI.
- `adminUiSourcePath`, `adminUiSourceUrl`, `adminUiSourceSha256`, `adminUiCacheDir`: legacy-импорт источников для Admin UI.
- `authProvider`, `complianceRequirements`, `a11yLevel`, `language`, `framework`, `database`, `hosting`, `sharedTypesPath`: значения, которые подставляются в сгенерированную документацию.

Смотри [project.config.example.json](./project.config.example.json).

## Цели Установки И Наборы

Выбор targets:

- Config: `"installTargets": ["copilot", "claude", "codex"]`
- PowerShell: `-InstallTargets copilot,claude,codex`
- Python: `--install-targets copilot,claude,codex`

CLI-флаги целей переопределяют цели из конфигурации. Они не объединяются со значениями из config.

Правила наборов:

- `session-state` включается всегда.
- `admin-ui-foundation` включается по умолчанию, если `adminUiBase` не равен `none`.
- `agent-memory` включается только явно и ставит layered memory/provider инструкции для cross-session continuity.
- `cloakmcp` включается только явно и ставит secret sanitization инструкции для CloakMCP-style local-first workflows.
- `codegraph` включается только явно и ставит graph-first инструкции для внешнего инструмента CodeGraph.
- `jira` включается только явно.
- `knowledge-foundation` включается только явно и ставит локальную файловую wiki вместе с папкой для raw-материалов.
- `markitdown` включается только явно и ставит инструкции document-to-Markdown ingestion для внешнего инструмента MarkItDown.
- `research-engine` включается только явно и ставит research/answer-engine инструкции для source-cited planning workflows.
- `specflow` включается только явно и ставит документы spec-driven workflow, правила артефактов и checklist gates.
- `video-ops` включается только явно.
- Метаданные наборов лежат в `templates/packs/<pack>/pack.json`. Используйте `--list-packs` / `-ListPacks`, чтобы посмотреть доступный registry.
- Правила создания наборов описаны в [docs/PACK_REGISTRY.md](./docs/PACK_REGISTRY.md).

Включить дополнительные наборы:

```powershell
pwsh ./scripts/install.ps1 -ListPacks
py -3 ./scripts/install.py --list-packs
py -3 ./scripts/install.py --list-packs-json
pwsh ./scripts/install.ps1 -ConfigPath ./project.config.json -EnablePack agent-memory -Diff
py -3 ./scripts/install.py ./project.config.json --enable-pack agent-memory --diff
pwsh ./scripts/install.ps1 -ConfigPath ./project.config.json -EnablePack cloakmcp -Diff
py -3 ./scripts/install.py ./project.config.json --enable-pack cloakmcp --diff
pwsh ./scripts/install.ps1 -ConfigPath ./project.config.json -EnablePack research-engine -Diff
py -3 ./scripts/install.py ./project.config.json --enable-pack research-engine --diff
py -3 ./scripts/install.py ./project.config.json --enable-pack codegraph,markitdown --check-tools
pwsh ./scripts/install.ps1 -ConfigPath ./project.config.json -EnablePack codegraph -Diff
py -3 ./scripts/install.py ./project.config.json --enable-pack codegraph --diff
pwsh ./scripts/install.ps1 -ConfigPath ./project.config.json -EnablePack markitdown -Diff
py -3 ./scripts/install.py ./project.config.json --enable-pack markitdown --diff
pwsh ./scripts/install.ps1 -ConfigPath ./project.config.json -EnablePack jira,video-ops
py -3 ./scripts/install.py ./project.config.json --enable-pack jira,video-ops
pwsh ./scripts/install.ps1 -ConfigPath ./project.config.json -EnablePack specflow -Diff
py -3 ./scripts/install.py ./project.config.json --enable-pack specflow --diff
pwsh ./scripts/install.ps1 -ConfigPath ./project.config.json -InstallPacks knowledge-foundation -KnowledgeRoot .ai/knowledge
py -3 ./scripts/install.py ./project.config.json --install-packs knowledge-foundation --knowledge-root .ai/knowledge
```

## Набор SpecFlow

`specflow` добавляет легкий spec-driven workflow, вдохновленный executable specification kits, но остается родным для этого installer-а. Он ставит документы в `.ai/shared-docs/` для:

- структуры `specs/<work-id>/`;
- артефактов `spec.md`, `plan.md`, `tasks.md`, `research.md`, `data-model.md`, `contracts/` и `quickstart.md`;
- checklist gates перед implementation;
- agent command intents вроде `specflow specify`, `specflow plan`, `specflow tasks` и `specflow implement`.
- Codex target skills: `specflow-specify`, `specflow-plan`, `specflow-tasks` и `specflow-implement`.

## Набор CodeGraph

`codegraph` добавляет инструкции для внешнего инструмента CodeGraph во время exploration и planning: symbol lookup, callers/callees, route discovery и impact analysis. Для Codex ставится skill `codegraph-explore`.

Installer не устанавливает CodeGraph и не копирует его source code. Установку нужно делать по upstream-инструкциям CodeGraph, а `.codegraph/` считать локальным runtime/index state, если целевой проект явно не описывает другую политику.

## Набор MarkItDown

`markitdown` добавляет инструкции для внешнего инструмента Microsoft MarkItDown как raw document-ingestion шага. Он полезен, когда контекст проекта лежит в PDF, Word, PowerPoint, Excel, HTML, CSV/JSON/XML, ZIP, EPub, transcript или похожих форматах.

Converted Markdown остается raw intake, пока его не проверили. Installer не устанавливает MarkItDown, не вызывает cloud-backed Azure conversion services автоматически и не перезаписывает curated knowledge files.

## Набор Agent Memory

`agent-memory` добавляет инструкции для cross-session recall, long-task offload, memory distillation и provider boundaries. Он разделяет слои `knowledge-foundation`, `session-state`, `agent-memory` и `codegraph`.

Рекомендованный режим по умолчанию — local layered memory. Внешние providers вроде Supermemory или TencentDB Agent Memory-style систем включаются только явно и должны быть описаны в проекте с privacy, scope, retention и uninstall boundaries.

## Набор CloakMCP

`cloakmcp` добавляет local-first secret sanitization инструкции для AI agent workflows. Он ставит docs для scanning, deterministic redaction, local vault boundaries, audit/runtime ignore rules и explicit unpack/disable boundaries, плюс Codex skill `secret-sanitize`.

Installer не устанавливает CloakMCP, не ставит hooks и не переписывает secrets автоматически.

## Набор Research Engine

`research-engine` добавляет инструкции для self-hosted или external answer engines вроде Vane перед specification, planning и tool selection work. Он отделяет source-cited research от CodeGraph, durable knowledge и agent memory.

Installer не устанавливает Vane или другой research engine автоматически.

## Локальная Wiki Знаний

`knowledge-foundation` — это локальная wiki знаний проекта, а не GitHub Wiki. Она создаёт внутри проекта корень вроде `.ai/knowledge/`:

- `raw/` — для сырых заметок, выгрузок, handoff-материалов и источников.
- `wiki/` — для проверенных фактов, решений, истории задач, открытых вопросов, архитектурных заметок и уроков агентов.
- `index/` — для карты файлов и порядка чтения.
- `.codex/project-context/dev/KNOWLEDGE-WORKFLOW.md` — для Codex, если установлен target `codex`.

P0-реализация файловая: без daemon и без SQLite/FTS индекса. Уже существующие knowledge-файлы инсталлер сохраняет и не перетирает.

## Режимы

- `-DryRun` / `--dry-run`: показывает запланированные действия установщика. Если нужен строгий запуск без записи и без создания bootstrap config, используй `-Diff` / `--diff`.
- `-Diff` / `--diff` / `--diff-mode`: строгий режим предпросмотра без записи; также отказывается создавать отсутствующую bootstrap-конфигурацию.
- `-UpdateOnly` / `--update-only`: обновляет только существующие файлы; отсутствующие файлы и папки пропускаются.
- `-AnalyzeProject` / `--analyze-project`: устанавливает templates и запускает анализ проекта.
- `-AnalyzeOnly` / `--analyze-only`: запускает только анализ, без установки templates.
- `-NoSecondStepPrompt` / `--no-second-step-prompt`: пропускает интерактивный вопрос второго этапа.

## Анализ Проекта

При включённом анализе установщик сканирует целевой проект и пишет:

- `.ai/shared-docs/project-overview.md`
- `.ai/shared-docs/analysis-summary.json`
- `.ai/shared-docs/modules/*.md`, если секции превышают threshold

Из сканирования исключаются сгенерированные, runtime- и cache-папки:

```text
.git, node_modules, dist, build, .venv, venv, target, out, .next,
.idea, .vscode, .ai, .codex, .claude, .tmp, .trash
```

Анализ ищет манифесты и точки входа: `package.json`, `pyproject.toml`, `go.mod`, `Cargo.toml`, Docker-файлы, Makefiles и CI workflows. Существующая Markdown-документация тоже используется как входные данные.

## Безопасность Сгенерированных Файлов

Установщик аккуратно относится к содержимому, которым владеет пользователь:

- `AGENTS.md` и `CLAUDE.md` обновляются через управляемые Markdown-блоки:
  - `<!-- BEGIN MANAGED: agent-orchestrator-installer root-agents -->`
  - `<!-- BEGIN MANAGED: agent-orchestrator-installer root-claude -->`
- Текст вне управляемых блоков сохраняется.
- Existing unmanaged `AGENTS.md` / `CLAUDE.md` пропускаются как conflicts, а не перезаписываются.
- `.ai/agent-orchestrator.lock.json` пишется после реальных запусков с записью и фиксирует фактические цели, наборы, режим и метаданные установщика.
- `-DryRun` и `-Diff` никогда не пишут lockfile.
- `-UpdateOnly` обновляет lockfile только если он уже существует.
- Python migration cleanup переносит legacy files в `<project>/.trash/<date>/...`; явная очистка trash выполняется отдельной maintenance-командой.
- `.trash/` игнорируется git. Для очистки старого trash используй `scripts/cleanup-trash.ps1` явно.

Очистка trash:

```powershell
pwsh ./scripts/cleanup-trash.ps1 -DryRun
pwsh ./scripts/cleanup-trash.ps1 -RetentionDays 7
```

## Пакет Для Админ-Интерфейсов

`admin-ui-foundation` — это дополнительный набор для проектов, в которых есть админка, панель управления или внутренний операторский интерфейс. Это не админка для самого installer, а проектный пакет правил и материалов для разработки рабочих интерфейсов: панелей управления, таблиц, фильтров, форм, карточек сущностей, списков пользователей, настроек и внутренних экранов.

AdminCore UI в этом репозитории означает базовую систему подходов для админ-интерфейсов: плотная и предсказуемая компоновка, упор на повторяемые рабочие сценарии, аккуратные таблицы и формы, понятная навигация, состояния загрузки/ошибок/пустых данных и единые правила для компонентов. Такой пакет полезен, когда AI-агентам нужно не “придумать красивую страницу”, а стабильно продолжать существующую админку или быстро собрать новую без хаоса в UX.

Что добавляет `admin-ui-foundation`:

- отдельного агента `admin-ui-agent` для задач по админ-интерфейсам;
- правила AdminCore UI для панелей управления и внутренних операторских экранов;
- документацию по компонентам, каталогам и примерам;
- материалы для canonical-режима, если переданы `component-examples.json` и `css-report.json`;
- ограничения и подсказки, чтобы агенты не делали маркетинговый лендинг вместо рабочей админки.

Включай этот набор, если в проекте есть или планируется админ-панель, CRM, панель управления или внутренний инструмент. Отключай через `adminUiBase=none`, если проекту не нужны материалы для админ-интерфейсов.

Поведение Admin UI по умолчанию:

- `admin-ui-foundation` включён, если `adminUiBase` не равен `none`.
- `adminUiMode=canonical` по умолчанию.
- В canonical-режиме установщик читает `component-examples.json` и `css-report.json` из `adminUiCanonicalDir` и копирует их в `.ai/shared-docs/tools/admincore-canonical/`.

Legacy-режим поддерживает импорт из папки с исходниками или из ZIP-архива:

- `-AdminUiSource` / `--admin-ui-source`
- `--admin-ui-source-url`
- `--admin-ui-sha256`
- `--admin-ui-cache-dir`

Используй `adminUiBase=none` или `-AdminUiBase none`, если проекту не нужны материалы для админ-интерфейса.

## Структура Сгенерированных Файлов

Типичный результат установки всех целей:

```text
<project>/
  AGENTS.md
  CLAUDE.md
  .codex/
    README.md
    agents/*.toml
    project-context/**
  .ai/
    agent-orchestrator.lock.json
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
      modules/*.md
      tools/**
      assets/**
  .tmp/
    agent-installer/**       # удалённый bootstrap/cache
  .trash/
    YYYY-MM-DD/**            # карантин для заменённых/убранных файлов
```

Глобальные skills для Codex копируются в `<user-codex-home>/skills/projects-*`.

## Команды

PowerShell:

```powershell
pwsh ./scripts/install.ps1 -ConfigPath ./project.config.json
pwsh ./scripts/install.ps1 -ConfigPath ./project.config.json -AnalyzeProject
pwsh ./scripts/install.ps1 -ConfigPath ./project.config.json -InstallTargets codex -UpdateOnly -NoSecondStepPrompt
pwsh ./scripts/install.ps1 -ConfigPath ./project.config.json -Diff -InstallTargets copilot
pwsh ./scripts/install.ps1 -ConfigPath ./project.config.json -AnalyzeProject -AdminUiBase none
```

Python:

```powershell
py -3 ./scripts/install.py ./project.config.json
py -3 ./scripts/install.py ./project.config.json --analyze-project
py -3 ./scripts/install.py ./project.config.json --install-targets codex --update-only --no-second-step-prompt
py -3 ./scripts/install.py ./project.config.json --diff --install-targets copilot
py -3 ./scripts/install.py ./project.config.json --analyze-project --admin-ui-base none
```

Shell wrapper:

```bash
bash ./scripts/install.sh ./project.config.json --analyze-project
```

CMD wrapper:

```bat
.\scripts\install.cmd .\project.config.json --analyze-project
```

## Локальный Web UI

Локальный Web UI — это тонкая браузерная оболочка над теми же Python-командами установщика. Используй его, когда нужен более спокойный операторский сценарий: выбрать наборы, проверить внешние tools и посмотреть diff перед настоящей установкой.

Запуск из репозитория installer-а:

```powershell
py -3 .\scripts\ui.py --host 127.0.0.1 --port 8765
```

Потом открой `http://127.0.0.1:8765`.

Чтобы браузер открылся автоматически:

```powershell
py -3 .\scripts\ui.py --open
```

Smoke-test для UI/API wrapper:

```powershell
py -3 .\scripts\smoke-ui.py
```

Текущие действия UI:

- загрузить registry наборов через `--list-packs-json`;
- загрузить, проверить, собрать draft или сохранить выбранный JSON config и применить targets/packs из него в wizard;
- Save записывает только `installTargets` и `enabledPacks`, требует явное подтверждение и сначала создаёт `.bak` файл.
- проверить внешние tools для выбранных наборов через `--check-tools`;
- запускать режимы установщика через тот же Python CLI: `--diff`, `--dry-run`, реальную установку, `--update-only`, `--analyze-project` и `--analyze-only`.
- показывать вывод команд через локальные background jobs во время долгих запусков installer-а.
- требовать явное подтверждение записи для install, update и analysis режимов.

CLI остаётся источником истины. Будущие desktop-оболочки вроде WebView2 или Tauri должны открывать этот же локальный Web UI, а не заново реализовывать логику installer-а.

## Справка

```powershell
Get-Help .\scripts\install.ps1 -Detailed
py -3 .\scripts\install.py --help
```

## Стартовый Prompt Для Orchestrator

Вставь это в AI-агент для кода после установки проектного набора:

```text
Работай строго как Orchestrator для этого проекта. Сначала прочитай .ai/shared-docs/project-overview.md и все project *.md docs. Работу по реализации делегируй сабагентам асинхронно, оставайся доступным в чате, давай короткие статус-апдейты и сразу докладывай результаты каждого сабагента. Соблюдай git policy проекта: task branch -> PR -> merge в main.
```

## Roadmap

Будущие интеграции и отложенные профили ведутся в [ROADMAP.md](./ROADMAP.md).
