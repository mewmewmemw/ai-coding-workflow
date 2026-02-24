# Claude Code: справочник по примитивам

> Companion-документ к `research-claude-code-implementation.md`. Содержит детальный reference по всем примитивам Claude Code.
> Известные баги и workarounds — см. `research-cc-known-issues.md`.

> Верифицировано по версии **v2.1.50-51** (февраль 2026). Шесть раундов ревью (exa + context7 + GitHub issues + WebFetch official docs, 5 параллельных агентов верификации).

---

## Subagents: frontmatter reference

Все поля frontmatter (13 полей в официальной reference table + `color` работает на практике):

| Поле | Обязательное | Значения | Описание |
|---|---|---|---|
| `name` | да | строка (lowercase letters and hyphens — official docs). ⚠️ Plugin-dev SKILL.md добавляет: numbers, 3-50 символов, алфавитно-цифровое начало/конец — но в official reference table этих ограничений нет | Идентификатор субагента |
| `description` | да | строка | По этому полю Claude решает, когда делегировать задачу |
| `model` | нет | `haiku`, `sonnet`, `opus`, `inherit` | `inherit` — наследует от родителя (default) |
| `tools` | нет | массив или строка. Поддерживает синтаксис `Task(agent_type)` для ограничения спауна субагентов (только `claude --agent`) | Ограничивает доступные инструменты (whitelist). ⚠️ Не блокирует MCP-инструменты (Issue #25589) |
| `disallowedTools` | нет | массив или строка | Запрещает конкретные инструменты (blacklist). ⚠️ Не блокирует MCP-инструменты (Issue #25589) |
| `isolation` | нет | `worktree` | Запускает субагента в изолированном git worktree |
| `hooks` | нет | объект (как в settings.json) | Hooks, привязанные к жизненному циклу субагента |
| `maxTurns` | нет | число | Максимальное количество turn-ов (лимит работы субагента) |
| `permissionMode` | нет | `default`, `acceptEdits`, `dontAsk`, `bypassPermissions`, `plan` | Режим разрешений для субагента |
| `mcpServers` | нет | объект (имя сервера → ссылка на уже настроенный сервер или inline definition с полной конфигурацией) | MCP-серверы, доступные субагенту |
| `skills` | нет | массив | Skills, доступные субагенту. Полный контент SKILL.md инжектируется при старте (не только description). ⚠️ Субагенты **не наследуют** skills от родительской сессии — нужно указывать явно |
| `memory` | нет | enum: `user`, `project`, `local`. Пути: `user` → `~/.claude/agent-memory/<name>/`, `project` → `.claude/agent-memory/<name>/`, `local` → `.claude/agent-memory-local/<name>/` | Включает персистентную директорию памяти. Автоматически включает Read, Write, Edit tools. Первые 200 строк `MEMORY.md` включаются в system prompt |
| `background` | нет | boolean (default: `false`) | `true` → запускает субагента как фоновую задачу. ⚠️ MCP tools недоступны в background subagents; неодобренные разрешения автоматически отклоняются; Stop hooks **не срабатывают** (Issue #25147) |

> **Про `color`:** Поле `color` работает на практике — quickstart упоминает "Choose a color: Pick a background color for the subagent", и используется в SKILL.md плагина plugin-dev. Конкретные значения (`blue`, `cyan`, `green`, `yellow`, `magenta`, `red`) — из observation/plugin-dev, official docs их не перечисляют. Поле **отсутствует** в официальной reference table "Supported frontmatter fields".

> **Важно про `description`:** Claude использует это поле для автоматического делегирования. Чем конкретнее описание, тем точнее срабатывает делегирование. Best practice: добавлять `<example>` блоки в body (из plugin-dev плагина; official docs не упоминают `<example>` явно).
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

### Built-in субагенты

| Субагент | Описание |
|---|---|
| `Explore` | Быстрое исследование кодовой базы (поиск файлов, grep, чтение) |
| `Plan` | Проектирование плана реализации |
| `general-purpose` | Универсальный агент для сложных многошаговых задач |
| `Bash` | Специалист по выполнению shell-команд |
| `statusline-setup` | Настройка status line в UI |
| `claude-code-guide` | Ответы на вопросы о Claude Code |

> **CLI `--agents` JSON:** Поддерживает **11 полей** (description, prompt, tools, disallowedTools, model, permissionMode, mcpServers, hooks, maxTurns, skills, memory). ⚠️ CLI reference table перечисляет 8 полей, но sub-agents page явно указывает все 11. Поля `background`, `isolation`, `color` — **только в file-based формате**. Вместо markdown body используется поле `prompt`.

---

## Hooks reference

### Полный список hook-событий (17 событий)

| Событие | Когда срабатывает | Может блокировать | Matcher |
|---|---|---|---|
| `SessionStart` | При старте/возобновлении сессии | Нет | `startup`, `resume`, `clear`, `compact` |
| `UserPromptSubmit` | При отправке промта, до обработки Claude | Да (exit 2 или JSON) | нет matcher |
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

// 3. agent — запускает субагента (использует prompt, не agent field, до 50 turns)
{ "type": "agent", "prompt": "Verify that all quality gates pass...", "timeout": 60 }
```

> **Response schema для prompt/agent hooks:** Модель должна вернуть JSON: `{ "ok": true }` → действие разрешено; `{ "ok": false, "reason": "..." }` → действие заблокировано, `reason` передаётся Claude. В prompt field можно использовать `$ARGUMENTS` — заменяется на JSON входных данных hook.

> **Common handler fields** (для всех типов): `type` (обязателен), `timeout` (seconds; defaults: 600 для command, 30 для prompt, 60 для agent), `statusMessage` (опционально, показывается юзеру во время выполнения), `once` (опционально, только для skills — запускается один раз за сессию, затем удаляется).
>
> ⚠️ **Не все события поддерживают все три типа.** Типы `prompt` и `agent` доступны только для 8 событий: `PermissionRequest`, `PostToolUse`, `PostToolUseFailure`, `PreToolUse`, `Stop`, `SubagentStop`, `TaskCompleted`, `UserPromptSubmit`. Остальные 9 событий поддерживают **только** `type: "command"`.
>
> ⚠️ **`type: "prompt"` опасен для ВСЕХ событий**: при сбое вызывает экспоненциальный рост payload и бесконечный retry loop (Issue #17249). **Рекомендация: `type: "command"` — единственный надёжный тип для production.**
>
> ⚠️ **SubagentStop hooks ненадёжны даже с `type: "command"`** — ~42% failure rate (Issue #27755). CI — обязательный fallback.

### Коды выхода для command-hooks

- `exit 0` — успех, stdout парсится как JSON для структурного контроля. ⚠️ Для большинства событий stdout видим только в verbose mode (`Ctrl+O`). Исключения: `UserPromptSubmit` и `SessionStart` — stdout добавляется как контекст, который Claude видит и на который может реагировать
- `exit 2` — блокирующая ошибка, stderr передаётся обратно Claude (stdout и JSON в нём **игнорируются**)
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
| `PostToolUse` | `decision` | `"block"` (feedback) / undefined. Доп. поля: `reason` (объяснение для Claude при block), `additionalContext`, `updatedMCPToolOutput` |
| `PostToolUseFailure` | — | Только `additionalContext` (через `hookSpecificOutput`). ⚠️ Official docs группируют с top-level decision events, но конкретная секция документирует только `additionalContext` |
| `Stop` / `SubagentStop` | `decision` | `"block"` / undefined. `"reason"` обязателен при block. Нет значения `"approve"` |
| `ConfigChange` | `decision` | `"block"` (блокирует изменение конфига, кроме `policy_settings`) / undefined |

> ⚠️ При использовании `hookSpecificOutput` необходимо включить поле `hookEventName` с именем события.
>
> **Дополнительные output-поля:** `SessionStart`, `SubagentStart` и `Notification` также поддерживают `additionalContext` через `hookSpecificOutput` (без decision control). `UserPromptSubmit` — `additionalContext` тоже через `hookSpecificOutput`, не top-level.
>
> **WorktreeCreate — уникальный механизм:** hook **заменяет** стандартное создание worktree. stdout должен содержать **только** абсолютный путь к созданному worktree. Non-zero exit = worktree не создаётся. Это не стандартный allow/block — hook сам отвечает за создание worktree.

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

> ⚠️ **Ограничения async hooks:** не могут блокировать действия или возвращать decisions. К моменту завершения hook триггерящее действие уже выполнено. Результат доставляется Claude на следующем turn; если сессия idle — ждёт следующего взаимодействия. Каждое срабатывание создаёт отдельный background-процесс без дедупликации.

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
- `SessionStart`: `source`, `model`, опционально `agent_type`
- `UserPromptSubmit`: `prompt`
- `PreToolUse`: `tool_name`, `tool_input`, `tool_use_id`
- `PermissionRequest`: `tool_name`, `tool_input`, `permission_suggestions`
- `PostToolUse`: `tool_name`, `tool_input`, `tool_response`, `tool_use_id`
- `PostToolUseFailure`: `tool_name`, `tool_input`, `tool_use_id`, `error`, `is_interrupt`
- `Notification`: `message`, `title`, `notification_type`
- `SubagentStart`: `agent_id`, `agent_type`
- `SubagentStop`: `agent_id`, `agent_type`, `agent_transcript_path`, `last_assistant_message`, `stop_hook_active`
- `Stop`: `last_assistant_message`, `stop_hook_active`
- `TaskCompleted`: `task_id`, `task_subject`, `task_description`, `teammate_name`, `team_name`
- `TeammateIdle`: `teammate_name`, `team_name`
- `ConfigChange`: `source`, `file_path`
- `PreCompact`: `trigger`, `custom_instructions`
- `WorktreeCreate`: `name`
- `WorktreeRemove`: `worktree_path`
- `SessionEnd`: `reason`

> ⚠️ **PermissionRequest** hooks **не срабатывают** в non-interactive mode (`-p`). Для автоматических permission decisions используйте `PreToolUse` hooks.

### Настройка hooks

Hooks настраиваются через `.claude/settings.json` (project-level) или `~/.claude/settings.json` (user-level). Интерфейс `/config` в TUI позволяет открыть файл настроек для редактирования.

> ⚠️ **Hooks snapshot:** Прямые правки hooks в settings файлах **не применяются мгновенно**. Claude Code захватывает snapshot hooks при старте сессии. При внешних изменениях выдаёт предупреждение и требует ревью в `/hooks` menu. Hooks, добавленные через `/hooks`, применяются мгновенно.
>
> **`disableAllHooks`** — поле в settings для временного отключения всех hooks. ⚠️ Учитывает иерархию managed settings: если hooks заданы через managed policy, `disableAllHooks` на уровне user/project/local **не может** их отключить.
>
> **`allowManagedHooksOnly`** — enterprise-настройка: блокирует user, project и plugin hooks, оставляя только managed.

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

**String substitutions в skills:**
- `$ARGUMENTS` — все аргументы пользователя после `/skill-name`
- `$ARGUMENTS[N]` или `$N` — N-й аргумент (0-indexed)
- `${CLAUDE_SESSION_ID}` — ID текущей сессии
- `` !`command` `` — динамическая инъекция: shell-команда выполняется перед отправкой контента Claude, stdout включается в промт

**Приоритет skills:** enterprise > personal > project. При конфликте имени skill > command. Skills из `--add-dir` директорий авто-загружаются с live change detection.

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
├── settings.json          ← Default agent settings (применяются при включении плагина)
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

**CLI-команды для плагинов:**
```bash
claude plugin install <plugin-name> [--scope user|project|local]
claude plugin uninstall <plugin-name>   # aliases: remove, rm
claude plugin enable <plugin-name>
claude plugin disable <plugin-name>
claude plugin update <plugin-name>
/plugin                                 # TUI → интерактивное управление
```

**Разработка:** `claude --plugin-dir ./my-plugin` — загрузка плагина из директории (только для текущей сессии).

**Маркетплейс:** Официальный marketplace `claude-plugins-official` содержит плагины для LSP-интеграций, внешних сервисов, workflow и output styles (точное количество не документировано).

---

## Settings: 5-уровневая иерархия

Настройки Claude Code работают в 5 скоупах (от высшего приоритета к низшему):

1. **Managed policy** (`managed-settings.json`) — корпоративные политики (самый высокий приоритет)
   - macOS: `/Library/Application Support/ClaudeCode/managed-settings.json`
   - Linux/WSL: `/etc/claude-code/managed-settings.json`
   - Windows: `C:\Program Files\ClaudeCode\managed-settings.json`
   - Также `managed-mcp.json` для MCP-конфигурации
2. **CLI arguments** — аргументы командной строки (временные, для текущей сессии)
3. **`.claude/settings.local.json`** — локальные настройки проекта (не коммитятся в git)
4. **`.claude/settings.json`** — настройки проекта (коммитятся в git)
5. **`~/.claude/settings.json`** — пользовательские настройки (lowest)

> **Правило:** hooks из `.claude/settings.json` коммитятся в репозиторий и работают для всей команды. Для локальных экспериментов — `.claude/settings.local.json`.

---

## Agent Teams

Экспериментальная фича — несколько независимых Claude Code сессий, работающих параллельно.

**Включение:**
```json
{ "env": { "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1" } }
```
или `export CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`

**Delegate Mode** (community-термин, НЕ в official docs): Ограничивает Lead координацией, запрещая прямое написание кода. `Shift+Tab` переключает permission modes в TUI (не специфично для Agent Teams). Official docs рекомендуют промт: "Wait for your teammates to complete their tasks before proceeding." Навигация между teammates: `Shift+Down`.

**Keyboard shortcuts:** `Shift+Down` — навигация между teammates (wraps back to lead), `Ctrl+T` — toggle task list (in-process mode), `Enter` — view teammate's session.

**Display modes:** Настройка `teammateMode` в settings или `--teammate-mode` CLI flag:
- `"in-process"` — в одном окне (любой терминал)
- `"tmux"` — Split panes (official name) через tmux **или iTerm2** (с `it2` CLI). Setting value `"tmux"`, но работает и с iTerm2. ⚠️ Не работает в VS Code terminal, Windows Terminal, Ghostty
- `"auto"` (default) — автовыбор

**Коммуникация:** через Mailbox-систему (message одному teammate или broadcast всем). ⚠️ SendMessage молча теряет сообщения при несовпадении имени получателя (Issue #25135). ⚠️ Messages могут отправляться по agentType вместо name, создавая orphan inboxes (Issue #25694).

**Official limitations (из документации):**
- No session resumption с in-process teammates — `/resume` и `/rewind` не восстанавливают
- Task status can lag — teammates иногда не отмечают задачи как завершённые
- Shutdown can be slow — teammates ждут окончания текущего запроса
- One team per session
- No nested teams — teammates не могут спаунить свои teams
- Lead is fixed — нельзя передать лидерство
- Permissions set at spawn — все стартуют с permission mode лида

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

## CLI-команды (v2.1.50-51, избранное)

> Полный список: https://code.claude.com/docs/en/cli-reference (40+ флагов), https://code.claude.com/docs/en/interactive-mode (25+ TUI-команд)

### Ключевые CLI-команды и флаги

| Команда / Флаг | Описание |
|---|---|
| `claude` | Запуск интерактивной сессии |
| `claude -p "prompt"` | Non-interactive (print) mode — выполнить промт и выйти |
| `claude -c` / `--continue` | Продолжить последнюю сессию |
| `claude -r` / `--resume` | Возобновить конкретную сессию по ID |
| `claude --model <model>` | Выбрать модель (sonnet, opus, haiku) |
| `claude --permission-mode <mode>` | default / acceptEdits / plan / dontAsk / bypassPermissions |
| `claude --agent <name>` | Запуск конкретного субагента как основного агента |
| `claude --agents '{JSON}'` | CLI-определение субагентов для текущей сессии |
| `claude --worktree` | Запуск в изолированном git worktree |
| `claude --remote` | Создание web-сессии на claude.ai |
| `claude --teleport` | Возобновление web-сессии в локальном терминале |
| `claude --add-dir <path>` | Добавить рабочую директорию (skills авто-загружаются) |
| `claude --max-turns <N>` | Максимум agentic turns |
| `claude --max-budget-usd <N>` | Лимит бюджета в USD |
| `claude --output-format json\|stream-json\|text` | Формат вывода (для non-interactive) |
| `claude --json-schema <schema>` | Structured JSON output по схеме |
| `claude --system-prompt "..."` | Кастомный system prompt |
| `claude --append-system-prompt "..."` | Дополнение к system prompt |
| `claude --allowedTools "tool1,tool2"` | Whitelist инструментов |
| `claude --disallowedTools "tool1"` | Blacklist инструментов |
| `claude --mcp-config <path>` | Загрузка MCP конфигурации из файла |
| `claude --plugin-dir <path>` | Загрузка плагина из директории |
| `claude --teammate-mode in-process\|tmux\|auto` | Режим отображения Agent Teams |
| `claude --verbose` | Расширенный вывод (hook output, etc.) |
| `claude --debug` | Отладка загрузки компонентов |
| `claude agents` | Просмотр всех настроенных агентов |
| `claude update` | Обновление Claude Code |
| `claude mcp` | Управление MCP серверами |
| `claude plugin install\|uninstall\|enable\|disable\|update` | Управление плагинами |

### Ключевые TUI slash-команды

| Команда | Описание |
|---|---|
| `/help` | Справка по командам |
| `/model` | Выбор / смена модели |
| `/permissions` | Просмотр / обновление разрешений |
| `/config` | Открыть settings interface |
| `/memory` | Редактирование CLAUDE.md файлов |
| `/hooks` | Управление hooks |
| `/plugin` | Интерактивное управление плагинами |
| `/stats` | Визуализация использования |
| `/cost` | Показать расход токенов |
| `/context` | Визуализация использования контекста |
| `/compact` | Компакция контекста |
| `/clear` | Очистка истории |
| `/resume` | Возобновление сессии |
| `/rewind` | Откат сессии |
| `/plan` | Вход в plan mode |
| `/export` | Экспорт разговора |
| `/init` | Инициализация проекта с CLAUDE.md |
| `/mcp` | Управление MCP серверами |
| `/tasks` | Список фоновых задач |
| `/teleport` | Возобновление remote-сессии |
| `/debug` | Отладка сессии |
| `/doctor` | Health check |
| `/vim` | Включение vim mode |
| `/statusline` | Настройка status line |
| `/theme` | Смена цветовой темы |

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
