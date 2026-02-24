# Критическое ревью документации

## Задача

Найти ВСЕ фактические ошибки, нестыковки, пробелы и устаревшую информацию в research-файлах этого репозитория. Для каждого утверждения, которое можно проверить — проверь через exa и WebFetch.

## Файлы для ревью

Все `.md` файлы в корне репозитория, за исключением `prompts/`:

- `methodology.md` — методология (эталон, проверяется на полноту маппинга)
- `research-claude-code-implementation.md` — маппинг методологии на примитивы Claude Code
- `research-cc-primitives-reference.md` — справочник по примитивам CC
- `research-cc-known-issues.md` — известные баги и workarounds

## Стратегия верификации

### Фаза 1: Параллельные агенты (5 направлений)

Запусти 5 субагентов параллельно. Каждый читает нужные файлы самостоятельно и верифицирует через official docs.

> **Правило: один агент — одна область.** Если два агента проверяют одно и то же, возникают конфликтующие выводы. Чёткие границы ниже.

#### Агент 1: Субагенты и frontmatter

Область: `research-cc-primitives-reference.md` → секция "Subagents"

Источники:
- WebFetch: `https://code.claude.com/docs/en/sub-agents`
- WebFetch: `https://code.claude.com/docs/en/permissions`
- exa: `site:code.claude.com/docs sub-agents OR subagents`

Проверить:
- Каждое поле frontmatter: существует ли, тип, допустимые значения, spelling
- Количество полей в official reference table vs в документе
- Новые поля, которых нет в документе
- Приоритет определений (CLI > project > user > plugin)
- `--agents` JSON: какие поля поддерживаются (сверить CLI reference и sub-agents page — они могут расходиться!)
- Ограничения: вложенные субагенты, Task в tools, background limitations
- `color` — в reference table или нет
- Resume механизм, auto-compaction
- Memory: пути директорий, auto-enabled tools, MEMORY.md limit

#### Агент 2: Hooks — события, JSON-формат, matchers

Область: `research-cc-primitives-reference.md` → секция "Hooks"

Источники:
- WebFetch: `https://code.claude.com/docs/en/hooks` (PRIMARY source of truth)
- exa: `site:code.claude.com/docs hooks`

Проверить:
- Полный список событий (сколько? не добавлены ли новые?)
- Для КАЖДОГО события: matcher-ы (ПОЛНЫЙ список!), типы обработчиков (command/prompt/agent), блокировка
- JSON decision fields для каждого события: точные поля, вложенность, допустимые значения
- Universal fields (continue, stopReason, suppressOutput, systemMessage)
- Common handler fields (type, timeout, statusMessage, once)
- Common input fields (что приходит на stdin для всех hooks)
- Per-event input fields (SubagentStop, Stop, TaskCompleted, etc.)
- Exit code семантику (0, 2, other)
- Async hooks
- hookSpecificOutput + hookEventName
- Deprecated fields (PreToolUse top-level decision/reason)
- Hooks snapshot behavior (применяются ли изменения без рестарта?)
- Prompt/agent hooks + SubagentStop — блокируют ли реально?

#### Агент 3: GitHub issues

Область: `research-cc-known-issues.md` — ВСЕ упомянутые issues

Источники:
- exa: `site:github.com/anthropics/claude-code/issues/{number}` для каждого issue
- WebFetch: `https://github.com/anthropics/claude-code/issues/{number}` для деталей

Проверить:
- Статус КАЖДОГО issue (open/closed/fixed)
- Совпадает ли описание бага с реальным issue
- Если closed — стал ли workaround ненужным?
- Новые критичные issues через exa: `site:github.com/anthropics/claude-code/issues` + keywords: `subagent bug`, `hooks bug`, `worktree bug`, `agent teams bug`, `skills plugins bug`

#### Агент 4: Skills, Plugins, Settings, CLI

Область: `research-cc-primitives-reference.md` → секции Skills, Plugins, Settings, CLI

Источники:
- WebFetch: `https://code.claude.com/docs/en/skills`
- WebFetch: `https://code.claude.com/docs/en/plugins-reference`
- WebFetch: `https://code.claude.com/docs/en/settings`
- WebFetch: `https://code.claude.com/docs/en/cli-reference`
- WebFetch: `https://code.claude.com/docs/en/interactive-mode`

Проверить:
- Skills: frontmatter поля (spelling! `user-invocable`, не `user-invokable`), progressive disclosure, commands/skills merger
- Plugins: plugin.json schema, структура директорий, установка
- Settings: иерархия приоритетов (сколько уровней, порядок), managed settings paths
- CLI: каждая команда и флаг — существует ли
- TUI slash-команды: какие built-in, какие пропущены
- Env vars: какие официально документированы, какие нет, новые

> **НЕ проверять**: Agent SDK, Agent Teams, Delegate Mode — это область Агента 5.

#### Агент 5: Agent SDK и Agent Teams

Область: `research-cc-primitives-reference.md` → секции Agent SDK, Agent Teams

Источники:
- WebFetch: `https://code.claude.com/docs/en/agent-teams`
- WebFetch: `https://platform.claude.com/docs/en/agent-sdk/typescript`
- WebFetch: `https://platform.claude.com/docs/en/agent-sdk/subagents`
- exa: `npmjs.com @anthropic-ai/claude-agent-sdk`

Проверить:
- SDK: import paths (TS и Python), API functions (query, createSdkMcpServer, tool), types, session management
- SDK: code examples — компилируемы ли, актуален ли API
- SDK: HookEvent type — сколько событий из 17 доступны программно
- SDK: новые возможности (V2 preview, outputFormat, canUseTool, etc.)
- Agent Teams: env var для включения, Delegate Mode (есть ли в OFFICIAL docs или только community?), Shift+Tab vs Shift+Down
- Agent Teams: limitations (один team, no nested, fixed lead, permissions, split panes)
- Agent Teams: коммуникация (Mailbox, SendMessage)

> **Ключевой паттерн ошибок:** community-sourced утверждения (claudefast.com, etc.) часто приписываются official docs. Всегда проверять, есть ли claim НА САМОЙ странице official docs, а не только "mentioned somewhere".

### Фаза 2: Ручная проверка (основной агент)

После получения результатов от всех 5 агентов, основной агент выполняет:

1. **Разрешение конфликтов** — если два агента дают разные выводы по одному claim, перепроверить первоисточник
2. **Внутренняя согласованность** — cross-references между тремя research-файлами
3. **Полнота маппинга** — все ли концепции methodology.md покрыты в research файлах
4. **Практическая реализуемость** — можно ли запустить описанный workflow

## Правила для агентов

1. **Primary source = official docs** (code.claude.com/docs/en/*). Загружать через WebFetch
2. **Secondary source = GitHub issues/repo** (anthropics/claude-code). Искать через exa
3. **Third-party sources** (claudefast.com, community guides) — только для контекста, НЕ как proof
4. **Для каждого утверждения**: CONFIRMED / CONTRADICTED / UNVERIFIABLE + источник
5. Проверять не только "что написано", но и **"что пропущено"** — новые поля, события, баги
6. **Не доверять training data** — загружать official docs через WebFetch

## Типичные паттерны ошибок (из предыдущих ревью)

> Эти паттерны обнаружены в предыдущих раундах верификации. Обращай на них особое внимание.

- **Community ≠ Official**: термины и фичи из community-блогов (claudefast.com) приписываются official docs
- **CLI reference ≠ Feature page**: CLI reference может перечислять меньше полей/флагов, чем feature-specific страница (пример: --agents fields)
- **Blocking mechanisms**: не все события блокируют одинаково; PermissionRequest блокирует и через exit 2, и через JSON
- **Deprecated fields**: PreToolUse имеет deprecated top-level decision/reason (→ hookSpecificOutput)
- **Sync vs Async**: systemMessage ведёт себя иначе для async hooks
- **SDK ≠ CLI**: SDK может не поддерживать все фичи CLI (пример: HookEvent type — 12/17 событий, dontAsk не в TS PermissionMode type)
- **Конкретные числа**: "~30 plugins", "3-50 chars" — часто из неверифицируемых источников
- **Worktree ecosystem**: множество связанных багов, новые появляются регулярно
- **"Нельзя"**: проверять, что именно "нельзя" — вызывает ошибку, игнорируется, или просто не рекомендуется

## Формат вывода

Для каждой найденной проблемы:

**[CRITICAL/WARNING/INFO/UNVERIFIABLE]** Краткое описание

- **Где:** файл:строка или секция
- **Что написано:** цитата из документа
- **Что на самом деле:** факт из официального источника (с URL)
- **Исправление:** конкретное предложение

В конце — общая оценка:

- Количество проблем по категориям (таблица)
- Главные риски при реальном использовании (топ-5)
- Что добавить / убрать / переписать (конкретный список)

## Режим работы

- **По умолчанию:** только найти и описать проблемы, НЕ исправлять файлы
- **Если пользователь просит исправить:** применить все исправления, обновить MEMORY.md, закоммитить
