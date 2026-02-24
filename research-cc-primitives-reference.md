# Claude Code: справочник по примитивам

> Companion-документ к `research-claude-code-implementation.md`. Содержит детальный reference по всем примитивам Claude Code.
> Известные баги и workarounds — см. `research-cc-known-issues.md`.

> Верифицировано по версии **v2.1.50-51** (февраль 2026). Четыре раунда ревью (exa + context7 + GitHub issues, 5 параллельных агентов верификации).

---

## Subagents: frontmatter reference

Все поля frontmatter (13 полей в официальной reference table + `color` работает на практике):

| Поле | Обязательное | Значения | Описание |
|---|---|---|---|
| `name` | да | строка (lowercase letters and hyphens — official docs). ⚠️ Plugin-dev SKILL.md добавляет: numbers, 3-50 символов, алфавитно-цифровое начало/конец — но в official reference table этих ограничений нет | Идентификатор субагента |
| `description` | да | строка + `<example>` блоки | По этому полю Claude решает, когда делегировать задачу |
| `model` | нет | `haiku`, `sonnet`, `opus`, `inherit` | `inherit` — наследует от родителя (default) |
| `tools` | нет | массив или строка. Поддерживает синтаксис `Task(agent_type)` для ограничения спауна субагентов (только `claude --agent`) | Ограничивает доступные инструменты (whitelist). ⚠️ Не блокирует MCP-инструменты (Issue #25589) |
| `disallowedTools` | нет | массив или строка | Запрещает конкретные инструменты (blacklist). ⚠️ Не блокирует MCP-инструменты (Issue #25589) |
| `isolation` | нет | `worktree` | Запускает субагента в изолированном git worktree |
| `hooks` | нет | объект (как в settings.json) | Hooks, привязанные к жизненному циклу субагента |
| `maxTurns` | нет | число | Максимальное количество turn-ов (лимит работы субагента) |
| `permissionMode` | нет | `default`, `acceptEdits`, `dontAsk`, `bypassPermissions`, `plan`. ⚠️ `dontAsk` полностью работает в CLI/frontmatter, но TypeScript SDK `PermissionMode` type definition содержит только `default`/`acceptEdits`/`bypassPermissions`/`plan` — при программном использовании SDK `dontAsk` может не поддерживаться | Режим разрешений для субагента |
| `mcpServers` | нет | объект (имя сервера → ссылка на уже настроенный сервер или inline definition с полной конфигурацией) | MCP-серверы, доступные субагенту |
| `skills` | нет | массив | Skills, доступные субагенту. Полный контент SKILL.md инжектируется при старте (не только description) |
| `memory` | нет | enum: `user`, `project`, `local`. Пути: `user` → `~/.claude/agent-memory/<name>/`, `project` → `.claude/agent-memory/<name>/`, `local` → `.claude/agent-memory-local/<name>/` | Включает персистентную директорию памяти. Автоматически включает Read, Write, Edit tools. Первые 200 строк `MEMORY.md` включаются в system prompt |
| `background` | нет | boolean (default: `false`) | `true` → запускает субагента как фоновую задачу. ⚠️ MCP tools недоступны в background subagents; неодобренные разрешения автоматически отклоняются; Stop hooks **не срабатывают** (Issue #25147) |

> **Про `color`:** Поле `color` работает на практике — quickstart упоминает "Choose a color: Pick a background color for the subagent", и используется в SKILL.md плагина plugin-dev. Конкретные значения (`blue`, `cyan`, `green`, `yellow`, `magenta`, `red`) — из observation/plugin-dev, official docs их не перечисляют. Поле **отсутствует** в официальной reference table "Supported frontmatter fields".

> **Важно про `description`:** Claude использует это поле для автоматического делегирования. Чем конкретнее описание, тем точнее срабатывает делегирование. Рекомендуется добавлять `<example>` блоки (best practice из plugin-dev плагина; official docs не упоминают `<example>` явно).
>
> **Важно про `tools`:** Субагенты **не могут** спаунить собственных субагентов. Включение `Task` в `tools` субагента не вызывает ошибку, но **игнорируется**. Синтаксис `Task(agent_type)` применим только для main-thread агента (`claude --agent`): `tools: Task(worker, researcher), Read, Bash`.
>
> **Отключение субагентов через settings:** `"permissions": { "deny": ["Task(Explore)", "Task(my-custom-agent)"] }` или `--disallowedTools "Task(Explore)"`.
>
> **Приоритет определений:** CLI (`--agents`) > project (`.claude/agents/`) > user (`~/.claude/agents/`) > plugin
>
> **Resume и транскрипты:** Субагенты можно resume с полной историей. Транскрипты хранятся в `~/.claude/projects/{project}/{sessionId}/subagents/agent-{agentId}.jsonl`. ⚠️ Resume ломается при 3+ tool uses в первом вызове (Issue #20942).
>
> **Auto-compaction:** Субагенты поддерживают auto-compaction при ~95% ёмкости контекста, настраивается через `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE`.
>
> **CLI `--agents` JSON:** Поддерживает **11 полей** (description, prompt, tools, disallowedTools, model, permissionMode, mcpServers, hooks, maxTurns, skills, memory). ⚠️ CLI reference table перечисляет 8 полей, но sub-agents page явно указывает все 11. Поля `background`, `isolation`, `color` — **только в file-based формате**. Вместо markdown body используется поле `prompt`.

---

## Hooks reference

### Полный список hook-событий (17 событий)

| Событие | Когда срабатывает | Может блокировать | Matcher |
|---|---|---|---|
| `SessionStart` | При старте/возобновлении сессии | Нет | `startup`, `resume`, `clear`, `compact` |
| `UserPromptSubmit` | При отправке промта, до обработки Claude | Да (exit 2) | нет matcher |
| `PreToolUse` | Перед выполнением tool-вызова | Да (exit 2 или JSON) | имя инструмента: `Bash`, `Read`, `Edit`, `Write`, `Glob`, `Grep`, `Task`, `WebFetch`, `WebSearch`, `Edit\|Write`, `mcp__.*` и любые MCP tool names |
| `PermissionRequest` | При появлении диалога разрешения | Да (exit 2 или JSON) | имя инструмента |
| `PostToolUse` | После успешного tool-вызова | Нет (но feedback через JSON) | имя инструмента |
| `PostToolUseFailure` | После неудачного tool-вызова | Нет | имя инструмента |
| `Notification` | Когда Claude Code отправляет уведомление | Нет | тип: `permission_prompt`, `idle_prompt`, `auth_success`, `elicitation_dialog` |
| `SubagentStart` | При запуске субагента | Нет | тип агента: `Bash`, `Explore`, `Plan`, custom names |
| `SubagentStop` | При завершении субагента | Да (exit 2 или JSON) | тип агента (`agent_type`): `Bash`, `Explore`, `Plan`, custom names |
| `Stop` | Когда Claude завершает ответ | Да (exit 2 или JSON) | нет matcher |
| `TeammateIdle` | Когда teammate в Agent Teams уходит в idle | Да (exit 2) | нет matcher |
| `TaskCompleted` | Когда задача помечается как завершённая | Да (exit 2) | нет matcher |
| `ConfigChange` | При изменении конфига во время сессии | Да (exit 2 или JSON `decision: "block"`), кроме `policy_settings` | `user_settings`, `project_settings`, `local_settings`, `policy_settings`, `skills` |
| `WorktreeCreate` | При создании worktree | Да (заменяет git) | нет matcher |
| `WorktreeRemove` | При удалении worktree | Нет | нет matcher |
| `PreCompact` | Перед компакцией контекста | Нет | `manual`, `auto` |
| `SessionEnd` | При завершении сессии | Нет | `clear`, `logout`, `prompt_input_exit`, `bypass_permissions_disabled`, `other` |

### Типы hook-обработчиков

```json
// 1. command — shell-команда (основной вариант, поддерживается ВСЕМИ событиями)
{ "type": "command", "command": ".claude/hooks/my-script.sh" }

// 2. prompt — LLM-оценка (⚠️ ОПАСНО — см. ниже)
{ "type": "prompt", "prompt": "..." }

// 3. agent — запускает субагента
{ "type": "agent", "agent": "quality-gate-agent" }
```

> **Common handler fields** (для всех типов): `type` (обязателен), `timeout` (ms; defaults: 600000 для command, 30000 для prompt, 60000 для agent), `statusMessage` (опционально, показывается юзеру во время выполнения), `once` (опционально, только для skills — запускается один раз за invocation).
>
> ⚠️ **Не все события поддерживают все три типа.** Типы `prompt` и `agent` доступны только для 8 событий: `PermissionRequest`, `PostToolUse`, `PostToolUseFailure`, `PreToolUse`, `Stop`, `SubagentStop`, `TaskCompleted`, `UserPromptSubmit`. Остальные 9 событий поддерживают **только** `type: "command"`.
>
> ⚠️ **`type: "prompt"` опасен для ВСЕХ событий**: при сбое вызывает экспоненциальный рост payload и бесконечный retry loop (Issue #17249). **Рекомендация: `type: "command"` — единственный надёжный тип для production.**
>
> ⚠️ **SubagentStop hooks ненадёжны даже с `type: "command"`** — ~42% failure rate (Issue #27755). CI — обязательный fallback.

### Коды выхода для command-hooks

- `exit 0` — успех, stdout парсится как JSON для структурного контроля
- `exit 2` — блокирующая ошибка, stderr передаётся обратно Claude
- любой другой — неблокирующая ошибка, stderr показывается юзеру, выполнение продолжается

### JSON: Universal Fields (доступны для ВСЕХ hook-типов)

```json
{
  "continue": true,         // false → Claude полностью останавливается
  "stopReason": "string",   // сообщение при continue:false (показывается юзеру, НЕ Claude)
  "suppressOutput": false,  // true → stdout скрыт из verbose mode output
  "systemMessage": "string" // предупреждение, показываемое юзеру (НЕ Claude). ⚠️ Для async hooks — доставляется Claude как контекст
}
```

### JSON: решения по типам событий

| Событие | Поля решения | Значения |
|---|---|---|
| `UserPromptSubmit` | `decision` | `"block"` / undefined. Доп. поля: `reason`, `additionalContext` |
| `PreToolUse` | `hookSpecificOutput.permissionDecision` | `"allow"` / `"deny"` / `"ask"`. Доп. поля: `permissionDecisionReason` (для allow/ask — юзеру; для deny — Claude), `updatedInput` (модификация tool input), `additionalContext`. ⚠️ Deprecated: top-level `decision`/`reason` (`approve`→`allow`, `block`→`deny`) |
| `PermissionRequest` | `hookSpecificOutput.decision.behavior` | `"allow"` / `"deny"`. Доп. поля: `updatedInput`, `updatedPermissions`, `message`, `interrupt` |
| `PostToolUse` | `decision` | `"block"` (feedback) / undefined. Доп. поля: `additionalContext`, `updatedMCPToolOutput` |
| `PostToolUseFailure` | — | Нет decision control. Доп. поля: `additionalContext` (через `hookSpecificOutput`) |
| `Stop` / `SubagentStop` | `decision` | `"block"` / undefined. `"reason"` обязателен при block. Нет значения `"approve"` |
| `ConfigChange` | `decision` | `"block"` (блокирует изменение конфига, кроме `policy_settings`) / undefined |

> ⚠️ При использовании `hookSpecificOutput` необходимо включить поле `hookEventName` с именем события.

### Приоритет механизмов контроля

1. `"continue": false` в JSON — полная остановка Claude
2. `"decision": "block"` в JSON — блокировка конкретного действия
3. Exit code `2` — блокировка через stderr

### Stop/SubagentStop: детали

- Блокировать: `{"decision": "block", "reason": "описание проблемы"}` (exit 0 + JSON)
- Разрешить: пустой stdout или `{}` (без поля `decision`)
- Альтернатива: exit code `2` + stderr → тоже блокирует
- `Stop` hooks для субагентов автоматически конвертируются в `SubagentStop`
- Проверяйте `stop_hook_active` во входном JSON для предотвращения бесконечных циклов

### Async hooks

По умолчанию hooks синхронные. `"async": true` запускает hook без блокировки сессии (только для `type: "command"`):

```json
{
  "type": "command",
  "command": ".claude/hooks/async-notify.sh",
  "async": true
}
```

Используй async для: уведомлений, логирования, аналитики.

### Hooks в frontmatter субагента

Hooks можно определять прямо в frontmatter (а не только в settings.json):

```markdown
---
name: backend-developer
description: Backend implementation specialist.
model: sonnet
tools: Read, Edit, Write, Bash, Glob, Grep
hooks:
  SubagentStop:
    - type: command
      command: .claude/hooks/quality-gate-subagent.sh
---
```

### Common input fields (stdin JSON для ВСЕХ событий)

Все hooks получают на stdin JSON со следующими common полями:

- `session_id` — ID текущей сессии
- `transcript_path` — путь к файлу транскрипта
- `cwd` — текущая рабочая директория
- `permission_mode` — текущий режим разрешений (включая `dontAsk`)
- `hook_event_name` — имя события

Дополнительные поля зависят от события:
- `SubagentStop`: `agent_id`, `agent_type`, `agent_transcript_path`, `last_assistant_message`, `stop_hook_active`
- `Stop`: `last_assistant_message`, `stop_hook_active`
- `TaskCompleted`: `task_id`, `task_subject`, `task_description`, `teammate_name`, `team_name`
- `TeammateIdle`: `teammate_name`, `team_name`
- `WorktreeCreate`: `name`
- `WorktreeRemove`: `worktree_path`

### Настройка hooks

Hooks настраиваются через `.claude/settings.json` (project-level) или `~/.claude/settings.json` (user-level). Интерфейс `/config` в TUI позволяет открыть файл настроек для редактирования.

> ⚠️ **Hooks snapshot:** Прямые правки hooks в settings файлах **не применяются мгновенно**. Claude Code захватывает snapshot hooks при старте сессии. Для применения изменений нужен рестарт или `/hooks` в TUI.
>
> **`disableAllHooks`** — поле в settings для временного отключения всех hooks.

### Переменные окружения в hooks

**Официально задокументированные:**
- `$CLAUDE_PROJECT_DIR` — корневая директория проекта (для портабельных путей)
- `$CLAUDE_PLUGIN_ROOT` — корневая директория плагина (для plugin hooks)
- `$CLAUDE_ENV_FILE` — путь к файлу для персистентных env vars (только в `SessionStart` hooks)
- `$CLAUDE_CODE_REMOTE` — `"true"` в remote web environments, не установлена в локальном CLI

**Получение tool input:**

Tool input передаётся через **JSON на stdin** (официальный механизм). `$CLAUDE_TOOL_INPUT_*` **не документированы** и не гарантированы (Issue #17637):

```bash
INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
```

---

## Skills reference

Skills = on-demand промт-расширение. Claude загружает `name` + `description` из frontmatter скиллов в начале сессии (кроме тех, у которых `disable-model-invocation: true`). Тело SKILL.md загружается **только** при вызове. Бюджет на описания: 2% от контекстного окна (fallback 16,000 символов, настраивается через `SLASH_COMMAND_TOOL_CHAR_BUDGET`).

**Три уровня progressive disclosure:**
1. **Frontmatter** (name, description) — всегда в контексте Claude
2. **Тело SKILL.md** — загружается при вызове скилла (рекомендация: < 500 строк)
3. **References/scripts** — загружаются по запросу внутри тела SKILL.md

**Frontmatter SKILL.md (полный список полей):**

| Поле | Обязательное | Описание |
|---|---|---|
| `name` | нет | Lowercase + hyphens + цифры, макс 64 символа. По умолчанию = имя директории |
| `description` | рекомендуется | Что делает + когда использовать. Основной триггер для Claude. При отсутствии — первый параграф контента |
| `model` | нет | Модель для выполнения (`inherit` по умолчанию) |
| `user-invocable` | нет | `false` → скрывает из `/` меню, но Claude может загружать автоматически |
| `disable-model-invocation` | нет | `true` → только через `/skill-name`, Claude не загружает автоматически, description не в контексте |
| `argument-hint` | нет | Подсказка в UI при вызове (например, `[test file] [options]`) |
| `allowed-tools` | нет | Инструменты без запроса разрешения при активном скилле (⚠️ баг Issue #14956) |
| `context` | нет | `"fork"` → запуск в изолированном subagent context |
| `agent` | нет | Какой субагент использовать при `context: fork` |
| `hooks` | нет | Lifecycle hooks, привязанные к скиллу |

> ⚠️ **Критический баг:** поле `allowed-tools` **ненадёжно** (Issue #14956). Для ограничения инструментов используйте **субагентов** (у них `tools` работает корректно).

**Слияние commands и skills:**
- `.claude/commands/research.md` и `.claude/skills/research/SKILL.md` — оба создают `/research`
- Существующие `.claude/commands/` файлы продолжают работать
- Skills добавляют: директорию для файлов, контроль invocation, авто-загрузку по описанию

---

## Plugins reference

Полноценная система плагинов для распространения конфигурации между проектами и командами.

**Структура плагина:**

```
my-plugin/
├── .claude-plugin/
│   └── plugin.json        ← ТОЛЬКО манифест здесь
├── commands/              ← НА КОРНЕВОМ уровне (не внутри .claude-plugin/)
├── agents/                ← НА КОРНЕВОМ уровне
├── skills/                ← НА КОРНЕВОМ уровне
├── hooks/                 ← НА КОРНЕВОМ уровне (или hooks.json)
├── scripts/               ← Вспомогательные скрипты
├── .mcp.json              ← MCP-серверы
├── .lsp.json              ← LSP-серверы
├── CHANGELOG.md
└── LICENSE
```

> ⚠️ **Частая ошибка:** компоненты (commands, agents, skills, hooks) должны быть на **корневом** уровне плагина, **НЕ** внутри `.claude-plugin/`. Только `plugin.json` живёт в `.claude-plugin/`.

**Манифест plugin.json:**
```json
{
  "name": "my-methodology-plugin",
  "version": "1.0.0",
  "description": "Context engineering methodology agents and hooks",
  "author": { "name": "Team", "email": "team@example.com" },
  "homepage": "https://github.com/team/plugin",
  "repository": "https://github.com/team/plugin",
  "license": "MIT",
  "keywords": ["methodology", "quality-gates", "research"],
  "commands": ["./commands/"],
  "agents": "./agents/",
  "skills": "./skills/",
  "hooks": "./hooks/hooks.json",
  "mcpServers": "./.mcp.json",
  "outputStyles": "./styles/",
  "lspServers": "./.lsp.json"
}
```

**Установка:**
```bash
claude plugin install <plugin-name>   # CLI
/plugin                               # TUI → Discover → Add
```

**Маркетплейс:** Официальный marketplace `claude-plugins-official` содержит плагины для LSP-интеграций, внешних сервисов, workflow и output styles (точное количество не документировано).

---

## Settings: 5-уровневая иерархия

Настройки Claude Code работают в 5 скоупах (от высшего приоритета к низшему):

1. **Managed policy** (`managed-settings.json`) — корпоративные политики (самый высокий приоритет)
2. **CLI arguments** — аргументы командной строки (временные, для текущей сессии)
3. **`.claude/settings.local.json`** — локальные настройки проекта (не коммитятся в git)
4. **`.claude/settings.json`** — настройки проекта (коммитятся в git)
5. **`~/.claude/settings.json`** — пользовательские настройки (lowest)

> **Правило:** hooks из `.claude/settings.json` коммитятся в репозиторий и работают для всей команды. Для локальных экспериментов — `.claude/settings.local.json`.

---

## Agent SDK (программная оркестрация)

```typescript
import { query } from "@anthropic-ai/claude-agent-sdk";

for await (const message of query({
  prompt: "Review auth module for security issues",
  options: {
    allowedTools: ["Read", "Grep", "Glob", "Task"],
    agents: {
      "code-reviewer": {
        description: "Expert code reviewer",
        prompt: "You are a senior code reviewer...",
        tools: ["Read", "Grep", "Glob", "Bash"],
        model: "sonnet"
      }
    }
  }
})) {
  // process messages
}
```

**Ключевые возможности SDK:**
- Программное определение субагентов через `agents` параметр
- Кастомные MCP-инструменты через `createSdkMcpServer()` + `tool()` helper
- Резюмирование сессий через `resume: sessionId` (+ `forkSession`, `resumeSessionAt`)
- Детекция контекста субагента через `parent_tool_use_id` поле в SDK message types (`SDKAssistantMessage`, `SDKUserMessage`)
- `canUseTool` — программный контроль разрешений
- `outputFormat: { type: 'json_schema', schema: JSONSchema }` — structured JSON output
- `sandbox` — настройка sandbox для выполнения команд
- `plugins: [{ type: "local", path: "./my-plugin" }]` — программная загрузка плагинов
- `betas: ['context-1m-2025-08-07']` — расширенный контекст до 1M токенов

**Python SDK** дополнительно предоставляет `ClaudeSDKClient` для multi-turn conversations с hooks и custom tools.

**V2 SDK preview (unstable):** `unstable_v2_prompt()`, `createSession()`/`resumeSession()`, `session.send()`/`session.stream()`.

> ⚠️ **SDK HookEvent type gap:** TypeScript SDK `HookEvent` поддерживает только **12 из 17** событий. Отсутствуют: `TeammateIdle`, `TaskCompleted`, `ConfigChange`, `WorktreeCreate`, `WorktreeRemove`. Это значит, что Agent Teams quality gates через `TeammateIdle` **невозможны** при программной оркестрации через SDK — только через `settings.json` command hooks.

**Official docs:**
- [Agent SDK — TypeScript](https://platform.claude.com/docs/en/agent-sdk/typescript)
- [Agent SDK — Subagents](https://platform.claude.com/docs/en/agent-sdk/subagents)

---

## Agent Teams

Экспериментальная фича — несколько независимых Claude Code сессий, работающих параллельно.

**Включение:**
```json
{ "env": { "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1" } }
```
или `export CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`

**Delegate Mode** (community-термин, НЕ в official docs): Ограничивает Lead координацией, запрещая прямое написание кода. `Shift+Tab` переключает permission modes в TUI (не специфично для Agent Teams). Official docs рекомендуют промт: "Wait for your teammates to complete their tasks before proceeding." Навигация между teammates: `Shift+Down`.

**Коммуникация:** через Mailbox-систему (message одному teammate или broadcast всем). ⚠️ SendMessage молча теряет сообщения при несовпадении имени получателя (Issue #25135).

**Паттерн Swarm через tmux** (community, без Agent Teams API):

```markdown
---
agent_name: backend-developer
task_number: 1
coordinator_session: lead-session
enabled: true
dependencies: []
---
```

Hook для нотификации координатора:
```bash
#!/bin/bash
STATE_FILE=".claude/agent-state.local.md"
if [[ ! -f "$STATE_FILE" ]]; then exit 0; fi

COORDINATOR=$(grep '^coordinator_session:' "$STATE_FILE" | sed 's/coordinator_session: *//')
AGENT=$(grep '^agent_name:' "$STATE_FILE" | sed 's/agent_name: *//')
ENABLED=$(grep '^enabled:' "$STATE_FILE" | sed 's/enabled: *//')

if [[ "$ENABLED" != "true" ]]; then exit 0; fi
if tmux has-session -t "$COORDINATOR" 2>/dev/null; then
  tmux send-keys -t "$COORDINATOR" "Agent $AGENT completed." Enter
fi
exit 0
```

---

## CLI-команды (v2.1.50-51)

| Команда | Описание |
|---|---|
| `claude agents` | Просмотр всех настроенных агентов (project + user + plugin) |
| `claude --worktree` | Запуск в изолированном git worktree |
| `claude --agents '{JSON}'` | CLI-определение субагентов для текущей сессии |
| `claude --agent <name>` | Запуск конкретного субагента как основного агента |
| `claude --remote` | Создание web-сессии на claude.ai с описанием задачи |
| `claude --teleport` | Возобновление web-сессии в локальном терминале |
| `/stats` | Визуализация использования: daily usage, session history, модели |
| `/plugin` | Интерактивное управление плагинами (4 вкладки: Discover, Installed, Marketplaces, Errors) |
| `claude --debug` | Отладка загрузки плагинов и компонентов (также `/debug` в TUI) |
| `/agents` | Интерактивное создание и управление субагентами в TUI |
| `/hooks` | Управление hooks в TUI |

---

## Sub-Agent Routing Rules (best practice для CLAUDE.md)

```markdown
## Sub-Agent Routing Rules

**Parallel dispatch** (ВСЕ условия должны быть выполнены):
- 3+ несвязанных задач или независимых доменов
- Нет shared state между задачами
- Чёткие файловые границы без пересечений

**Sequential dispatch** (ЛЮБОЕ условие триггерит):
- Задачи имеют зависимости (B нужен результат A)
- Общие файлы или state (риск merge-конфликтов)
- Неясный scope (нужно понять перед продолжением)

**Background dispatch**:
- Research или analysis задачи (не модификация файлов)
- Длительные операции (тесты, билды)
```
