# Реализация методологии контекстной инженерии в Claude Code

## Источники

### Официальная документация
- [Subagents](https://code.claude.com/docs/en/sub-agents)
- [Agent Teams](https://code.claude.com/docs/en/agent-teams)
- [Hooks reference](https://code.claude.com/docs/en/hooks)
- [Hooks guide](https://code.claude.com/docs/en/hooks-guide)
- [Skills](https://code.claude.com/docs/en/skills)
- [Plugins reference](https://code.claude.com/docs/en/plugins-reference)
- [Settings reference](https://code.claude.com/docs/en/settings)
- [Agent SDK — TypeScript](https://code.claude.com/docs/en/sdk/sdk-typescript)
- [Agent SDK — Subagents](https://docs.anthropic.com/en/docs/claude-code/sdk/subagents)

### Community-ресурсы
- [Everything Claude Code](https://github.com/affaan-m/everything-claude-code) — battle-tested конфигурации (1845 сниппетов)
- [Trail of Bits Claude Code Config](https://github.com/trailofbits/claude-code-config) — security-focused defaults
- [Awesome Claude Code Subagents](https://github.com/VoltAgent/awesome-claude-code-subagents) — 100+ субагентов (10.7K stars)
- [Claude Code Hooks Mastery](https://github.com/disler/claude-code-hooks-mastery) — все 17 hook-событий с примерами
- [Git Worktrees Complete Guide](https://notes.muthu.co/2026/02/the-complete-guide-to-git-worktrees-with-claude-code/)
- [Claude Code Agent Fundamentals](https://claudefa.st/blog/guide/agents/agent-fundamentals)
- [Agent Teams Controls](https://claudefa.st/blog/guide/agents/agent-teams-controls)
- [Agent Teams Best Practices](https://claudefa.st/blog/guide/agents/agent-teams-best-practices)
- [Self-Validating Agents](https://claudefa.st/blog/tools/hooks/self-validating-agents)
- [CLAUDE.md Complete Guide](https://www.claudedirectory.org/blog/claude-md-guide)
- [Anthropic Guide: Building Skills](https://resources.anthropic.com/hubfs/The-Complete-Guide-to-Building-Skill-for-Claude.pdf)

> Документ верифицирован по версии **v2.1.50-51** (февраль 2026). Последнее критическое ревью: 24 февраля 2026, второе ревью: 24 февраля 2026 (exa + context7 + GitHub issues, 5 параллельных агентов верификации). Исправления применены по результатам обоих ревью.

---

## Ключевые примитивы Claude Code

| Примитив | Что это | Где живёт |
|---|---|---|
| **CLAUDE.md** | Всегда загружается в начало каждой сессии. Глобальный контекст проекта. | `./CLAUDE.md`, `~/.claude/CLAUDE.md` |
| **Subagent** | Изолированный Claude-инстанс со своим контекстным окном, своими инструментами и системным промтом. Запускается внутри сессии. | `.claude/agents/*.md` или `~/.claude/agents/*.md` |
| **Agent Teams** | Несколько независимых Claude Code сессий, работающих параллельно. Могут общаться между собой. Экспериментальная фича. | Через `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` |
| **Skill** | Инструкции + исполняемые команды, загружаемые по необходимости. Вызываются через `/skill-name`. | `.claude/skills/{name}/SKILL.md` (или упрощённо: `.claude/commands/{name}.md`) |
| **Hook** | Shell-команда, выполняемая детерминированно в конкретный момент жизненного цикла агента. | `.claude/settings.json` или `~/.claude/settings.json` |
| **Plugin** | Пакет для распространения agents + skills + hooks + MCP серверов между проектами/командами. | `.claude-plugin/plugin.json` + компоненты в корне плагина |
| **Git Worktree** | Изолированная копия репозитория на отдельной ветке. Позволяет субагентам работать параллельно без конфликтов. | `claude --worktree` или `isolation: worktree` в subagent |

---

## Фаза 1: Research

### Механизм реализации: Custom Subagents + Параллельный запуск

Фаза Research реализуется через **кастомные субагенты**, каждый из которых получает узкое направление поиска. Lead-агент запускает их параллельно и собирает результаты в один документ.

### Файловая структура субагентов

```
.claude/
  agents/
    researcher-architecture.md
    researcher-domain-models.md
    researcher-integrations.md
    researcher-tests.md
```

### Формат файла субагента (.claude/agents/researcher-architecture.md)

Все поля frontmatter (13 полей в официальной reference table + `color` работает на практике):

| Поле | Обязательное | Значения | Описание |
|---|---|---|---|
| `name` | да | строка (lowercase + numbers + hyphens, 3-50 символов, начало и конец — алфавитно-цифровой) | Идентификатор субагента |
| `description` | да | строка + `<example>` блоки | По этому полю Claude решает, когда делегировать задачу |
| `model` | нет | `haiku`, `sonnet`, `opus`, `inherit` | `inherit` — наследует от родителя (default) |
| `tools` | нет | массив или строка | Ограничивает доступные инструменты (whitelist). ⚠️ Не блокирует MCP-инструменты (Issue #25589) |
| `disallowedTools` | нет | массив или строка | Запрещает конкретные инструменты (blacklist). ⚠️ Не блокирует MCP-инструменты (Issue #25589) |
| `isolation` | нет | `worktree` | Запускает субагента в изолированном git worktree |
| `hooks` | нет | объект (как в settings.json) | Hooks, привязанные к жизненному циклу субагента |
| `maxTurns` | нет | число | Максимальное количество turn-ов (лимит работы субагента) |
| `permissionMode` | нет | `default`, `acceptEdits`, `dontAsk`, `bypassPermissions`, `plan` | Режим разрешений для субагента |
| `mcpServers` | нет | объект | MCP-серверы, доступные субагенту |
| `skills` | нет | массив | Skills, доступные субагенту. Полный контент SKILL.md инжектируется при старте (не только description) |
| `memory` | нет | enum: `user`, `project`, `local` | Включает персистентную директорию памяти для субагента |
| `background` | нет | boolean (default: `false`) | `true` → запускает субагента как фоновую задачу |

> **Про `color`:** Поле `color` (`blue`, `cyan`, `green`, `yellow`, `magenta`, `red`) работает на практике и используется в официальных примерах и SKILL.md плагина plugin-dev, но **отсутствует** в официальной reference table "Supported frontmatter fields". Используйте — но знайте, что это недокументированное поле.

> **Важно про `description`:** Claude использует это поле для автоматического делегирования. Чем конкретнее описание, тем точнее срабатывает делегирование. Официально рекомендуется добавлять `<example>` блоки.
>
> **Важно про `tools`:** Субагенты **не могут** спаунить собственных субагентов — не включайте `Task` в массив `tools` субагента.
>
> **Приоритет определений:** CLI (`--agents`) > project (`.claude/agents/`) > user (`~/.claude/agents/`) > plugin

```markdown
---
name: researcher-architecture
description: |
  Research specialist for understanding system architecture. Use when exploring
  high-level structure, layers, entry points, and architectural patterns of the codebase.

  <example>
  Context: Need to understand how the payment module is structured
  user: "Research the architecture of our payment processing system"
  assistant: "I'll delegate this to the researcher-architecture agent to map the structure"
  <commentary>
  Architecture research tasks with no code writing should go to this agent
  </commentary>
  </example>
tools: Read, Glob, Grep, Bash
model: haiku
color: yellow
isolation: worktree
---

You are a codebase research specialist. Your ONLY job is to gather facts.

Rules:
- Describe only what EXISTS in the codebase AS IS
- NO opinions, suggestions, or "should be refactored" comments
- NO code generation
- Output only facts with file paths and line references

When invoked with a research task:
1. Map the relevant directory structure
2. Identify key files and their purposes
3. Note public interfaces and their signatures
4. Find all usages of relevant components
5. Document integration points and dependencies

Output format:
## Architecture Facts
- [fact with file:line reference]

## Entry Points
- [path:line] - [description]

## Key Interfaces
- [file:line] - [interface name and signature]

## Dependencies
- [what depends on what]
```

### Как Lead запускает параллельный Research

В промте Lead-агента (через Skill или CLAUDE.md):

```markdown
When given a task for Research phase:
1. Decompose the task into search dimensions (architecture, domain models, integrations, tests)
2. Spawn separate subagents for each dimension IN PARALLEL using the Task tool
3. Each subagent gets: the specific dimension + relevant file patterns to explore
4. Collect all results and merge into a single research document at docs/research/{task-name}.md
5. The research document contains ONLY facts with file:line references. Zero opinions.
```

### Модели для Research субагентов

- Используй `model: haiku` — Research субагенты не пишут код, только читают файлы
- Это снижает стоимость фазы в несколько раз

### Git Worktrees для изоляции

```yaml
# В frontmatter субагента
isolation: worktree
```

Это даёт каждому субагенту изолированную копию репозитория — важно при параллельном чтении больших кодовых баз. Каждый агент работает на своей ветке, без конфликтов при одновременных изменениях.

Либо через CLI:
```bash
claude --worktree
```

При использовании `isolation: worktree` автоматически срабатывают новые hook-события `WorktreeCreate` и `WorktreeRemove` (также добавлены в v2.1.50) — через них можно кастомизировать настройку worktree (например, для non-git VCS).

---

## Фаза 2: Design

### Механизм реализации: Skill + Standards в prompts/

Design-агент получает Research-документ и папку со стандартами команды. Стандарты хранятся как Skill или как набор файлов в `prompts/`.

### Структура стандартов команды

```
.claude/
  skills/
    team-standards.md   # Skill с архитектурными стандартами команды
prompts/
  architecture.md       # Паттерны слоёв, C4 правила
  domain-models.md      # Соглашения по доменным моделям
  testing.md            # Стратегия тестирования, правила покрытия
  naming.md             # Соглашения по именованию
  security.md           # Security checklist
  api-contracts.md      # Правила проектирования API
```

### Формат Design субагента (.claude/agents/designer.md)

```markdown
---
name: designer
description: Architecture designer. Use when creating architectural solution for a task. Requires research document as input.
tools: Read, Write, Glob
model: sonnet
---

You are a software architect. You create design documents BEFORE any code is written.

Input required:
- Research document (path to docs/research/{task}.md)
- Task description

Steps:
1. Read the research document completely
2. Read ALL files in prompts/ directory (team standards)
3. Generate architecture design to docs/design/{task}.md

Design document must include:
- C4 diagrams (Context → Containers → Components) in Mermaid
- Data Flow Diagrams where applicable
- Sequence Diagrams for key flows
- For complex features: ADR (Architecture Decision Record)
- Test strategy: what to test, key cases, coverage targets
- API contracts if applicable

CRITICAL: Design must comply with ALL standards from prompts/ directory.
CRITICAL: Do not write any code. Only design documents.

Output: docs/design/{task-name}.md
```

### Человеческий гейт после Design

После генерации дизайна — инженер ревьюирует документ руками. Часть правок вносится напрямую в markdown-файл. Это быстрее, чем перегенерировать.

---

## Фаза 3: Planning

### Механизм реализации: Skill + артефакты предыдущих фаз

Планировщик получает только два источника: Research-документ + утверждённый Design-документ. Он не читает кодовую базу.

### Формат Planning субагента (.claude/agents/planner.md)

```markdown
---
name: planner
description: Implementation planner. Use after design is approved to create detailed phased implementation plan. Requires research and design documents.
tools: Read, Write
model: sonnet
---

You are an implementation planner. You create detailed plans for human review BEFORE coding starts.

Input required:
- Research document: docs/research/{task}.md
- Design document: docs/design/{task}.md

Steps:
1. Read research document
2. Read design document
3. Generate phased implementation plan to docs/plan/{task}.md

Plan requirements:
- Split into PHASES, not one monolithic list
- Each phase is a complete, independently reviewable unit of work
- Each phase specifies:
  - Files to CREATE (with path)
  - Files to MODIFY (with path and what changes)
  - Methods/fields to ADD (with signatures)
  - Tests to WRITE
- Phases must be ordered by dependency (no circular deps)

CRITICAL: Do not write any code. Only the plan.
CRITICAL: Each phase must be completable and committable independently.

Output: docs/plan/{task-name}.md (split into phases)
```

### Человеческий гейт после Planning

Второй человеческий гейт. Инженер ревьюирует план: правит руками или через промт. Только после апрува — переход к Implementation.

---

## Фаза 4: Implementation

### Механизм реализации: Agent Teams + Hooks для quality gates

Implementation — это команда специализированных агентов. Два варианта в зависимости от сложности:

**Вариант A: Subagents** (проще, для большинства задач)
Lead запускает субагентов последовательно по фазам плана.

**Вариант B: Agent Teams** (для сложных задач с параллельной работой)
Полноценные Claude Code сессии, работающие параллельно и общающиеся между собой.

---

### Субагенты команды разработки

#### .claude/agents/backend-developer.md

```markdown
---
name: backend-developer
description: Backend code implementation specialist. Use to implement code changes according to a specific plan phase. Never reviews code, never writes tests.
tools: Read, Edit, Write, Bash, Glob, Grep
model: sonnet
---

You are a backend developer. You implement code STRICTLY according to the plan.

Input required:
- Plan phase document (specific phase from docs/plan/{task}.md)
- Design document: docs/design/{task}.md

Rules:
- Implement ONLY what is specified in the plan phase
- Do NOT deviate from the design document
- Do NOT write tests (that's the tester's job)
- Do NOT review your own code
- If something in the plan is unclear, note it and stop

After implementation:
- Run the build: report pass/fail
- Do NOT run tests yourself
```

#### .claude/agents/tester.md

```markdown
---
name: tester
description: Test writer and build runner. Use after backend-developer completes a phase. Writes tests and runs the full test suite. Never modifies production code.
tools: Read, Edit, Write, Bash, Glob, Grep
model: sonnet
---

You are a QA engineer. You write tests and run builds.

Rules:
- NEVER modify production code
- If tests fail because of a production code bug — report it with file:line, do not fix it yourself
- Write tests for ALL cases specified in the plan

Steps:
1. Read the plan phase to understand what was implemented
2. Write tests for the implemented functionality
3. Run the build: report pass/fail with full output
4. Run all tests: report pass/fail, list any failures with file:line
5. Report results
```

#### .claude/agents/arch-reviewer.md

```markdown
---
name: arch-reviewer
description: Architecture compliance reviewer. Use after tester completes. Checks that implementation matches the design document. Never modifies code.
tools: Read, Glob, Grep, Bash
model: sonnet
---

You are an architecture reviewer. You verify design compliance.

Rules:
- NEVER modify any code
- Only read and analyze
- Report findings as: [CRITICAL] / [WARNING] / [OK]

Review checklist:
1. Domain model matches design document (entities, relationships, value objects)
2. Layer boundaries respected (no cross-layer direct calls)
3. Architectural patterns applied correctly
4. Naming conventions from prompts/naming.md followed
5. API contracts match docs/design/{task}.md

Output: Structured report with file:line references for each issue
```

#### .claude/agents/security-reviewer.md

```markdown
---
name: security-reviewer
description: Security reviewer. Use after arch-reviewer. Checks for vulnerabilities in new code. Never modifies code.
tools: Read, Glob, Grep, Bash
model: sonnet
---

You are a security engineer. You review code for vulnerabilities.

Rules:
- NEVER modify any code
- Only read and analyze

Security checklist:
1. SQL injection vulnerabilities
2. XSS vulnerabilities
3. Command injection (unsanitized shell inputs)
4. Authentication/authorization flaws (unprotected endpoints)
5. Hardcoded secrets, API keys, credentials
6. Insecure data handling (logging sensitive data, unencrypted storage)
7. Input validation missing at system boundaries

Output: [CRITICAL] / [WARNING] / [OK] per finding with file:line
```

#### .claude/agents/plan-compliance.md

```markdown
---
name: plan-compliance
description: Plan compliance checker. Use as final check after all reviewers. Verifies everything in the plan phase was implemented. Never modifies code.
tools: Read, Glob, Grep
model: haiku
---

You are a plan compliance checker. You verify implementation completeness.

Steps:
1. Read the plan phase document
2. For each item in the plan, verify it exists in the code with file:line
3. List any items NOT implemented

Output:
## Implemented ✓
- [item] → [file:line]

## Missing ✗
- [item] → not found
```

---

### Hooks: Автоматические quality gates

Hooks обеспечивают детерминированный контроль — агент не может их обойти.

> **Два механизма блокировки:**
> - **Subagents** → `SubagentStop` hook. Два варианта: (1) exit code `2` + stderr → блокирует субагента, stderr передаётся Claude; (2) JSON `{"decision": "block", "reason": "..."}` в stdout при exit 0
> - **Agent Teams** → `TeammateIdle` hook, exit code `2` + stderr блокирует teammate
>
> **Также:** `Stop` hook работает аналогично `SubagentStop` — блокирует завершение основного агента. Для субагентов `Stop` hooks автоматически конвертируются в `SubagentStop`.

#### Полный список hook-событий (17 событий, верифицировано по официальной документации)

| Событие | Когда срабатывает | Может блокировать | Matcher |
|---|---|---|---|
| `SessionStart` | При старте/возобновлении сессии | Нет | `startup`, `resume`, `clear`, `compact` |
| `UserPromptSubmit` | При отправке промта, до обработки Claude | Да (exit 2) | нет matcher |
| `PreToolUse` | Перед выполнением tool-вызова | Да (exit 2 или JSON) | имя инструмента: `Bash`, `Edit\|Write`, `mcp__.*` |
| `PermissionRequest` | При появлении диалога разрешения | Да (JSON) | имя инструмента |
| `PostToolUse` | После успешного tool-вызова | Нет (но feedback через JSON) | имя инструмента |
| `PostToolUseFailure` | После неудачного tool-вызова | Нет | имя инструмента |
| `Notification` | Когда Claude Code отправляет уведомление | Нет | тип: `permission_prompt`, `idle_prompt`, `auth_success`, `elicitation_dialog` |
| `SubagentStart` | При запуске субагента | Нет | тип агента: `Bash`, `Explore`, `Plan`, custom names |
| `SubagentStop` | При завершении субагента | Да (exit 2 или JSON) | имя агента |
| `Stop` | Когда Claude завершает ответ | Да (exit 2 или JSON) | нет matcher |
| `TeammateIdle` | Когда teammate в Agent Teams уходит в idle | Да (exit 2) | нет matcher |
| `TaskCompleted` | Когда задача помечается как завершённая | Да (exit 2) | нет matcher |
| `ConfigChange` | При изменении конфига во время сессии | Нет | `user_settings`, `project_settings`, `local_settings`, `policy_settings`, `skills` |
| `WorktreeCreate` | При создании worktree | Да (заменяет git) | нет matcher |
| `WorktreeRemove` | При удалении worktree | Нет | нет matcher |
| `PreCompact` | Перед компакцией контекста | Нет | `manual`, `auto` |
| `SessionEnd` | При завершении сессии | Нет | `clear`, `logout`, `prompt_input_exit`, `bypass_permissions_disabled`, `other` |

#### Типы hook-обработчиков (три варианта)

```json
// 1. command — shell-команда (основной вариант, поддерживается ВСЕМИ событиями)
{ "type": "command", "command": ".claude/hooks/my-script.sh" }

// 2. prompt — LLM-оценка (для нетривиальных решений)
{ "type": "prompt", "prompt": "Проверь что тесты написаны для всех публичных методов. Если нет — block." }

// 3. agent — запускает субагента (для сложных проверок)
{ "type": "agent", "agent": "quality-gate-agent" }
```

> ⚠️ **Не все события поддерживают все три типа.** Типы `prompt` и `agent` доступны только для 8 событий: `PermissionRequest`, `PostToolUse`, `PostToolUseFailure`, `PreToolUse`, `Stop`, `SubagentStop`, `TaskCompleted`, `UserPromptSubmit`. Остальные 9 событий поддерживают **только** `type: "command"`.
>
> ⚠️ **КРИТИЧНО для quality gates:** `type: "prompt"` и `type: "agent"` для `SubagentStop` отправляют feedback, но **НЕ предотвращают завершение** субагента (Issue #20221, открыт). Для quality gates используйте **только** `type: "command"` с exit code 2 или JSON `{"decision": "block"}`.

#### settings.json — hooks для режима Subagents (основной вариант)

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": ".claude/hooks/lint-on-edit.sh"
          }
        ]
      }
    ],
    "SubagentStop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": ".claude/hooks/quality-gate-subagent.sh"
          }
        ]
      }
    ]
  }
}
```

#### .claude/hooks/quality-gate-subagent.sh

> **Формат JSON для Stop/SubagentStop** (верифицировано по официальной документации):
> - Блокировать: `{"decision": "block", "reason": "описание проблемы"}` — `reason` обязателен, передаётся Claude
> - Разрешить: пустой stdout или `{}` (без поля `decision`)
>
> **Альтернативный механизм:** exit code `2` + stderr → тоже блокирует, stderr передаётся Claude
>
> ⚠️ **НЕ существует** значения `"approve"` для Stop/SubagentStop. Для PreToolUse используется `hookSpecificOutput.permissionDecision` со значениями `"allow"` / `"deny"` / `"ask"` (см. таблицу ниже).
> ⚠️ Поле `"reason"` — для блокировки (передаётся Claude вместе с `"decision": "block"`). Поле `"systemMessage"` — отдельное универсальное поле (показывает предупреждение юзеру). Оба существуют, но имеют разное назначение.

```bash
#!/bin/bash
# Запускается когда субагент завершает работу (SubagentStop hook).
#
# Вариант 1 (JSON): exit 0 + JSON {"decision": "block", "reason": "..."} → субагент не останавливается
# Вариант 2 (exit code): exit 2 + stderr → субагент не останавливается, stderr идёт Claude
# exit 0 без JSON / с пустым stdout → субагент завершается нормально

# Читаем stdin (hook получает JSON с контекстом события)
INPUT=$(cat)

# Проверяем stop_hook_active чтобы избежать бесконечных циклов
STOP_HOOK_ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active // false')
if [ "$STOP_HOOK_ACTIVE" = "true" ]; then
  exit 0
fi

ERRORS=""

# 1. Build check
if ! npm run build > /tmp/build-output.txt 2>&1; then
  ERRORS="BUILD FAILED: $(tail -20 /tmp/build-output.txt)"
fi

# 2. Tests check
if [ -z "$ERRORS" ] && ! npm test > /tmp/test-output.txt 2>&1; then
  ERRORS="TESTS FAILED: $(tail -30 /tmp/test-output.txt)"
fi

# 3. Lint check
if [ -z "$ERRORS" ] && ! npm run lint > /tmp/lint-output.txt 2>&1; then
  ERRORS="LINT FAILED: $(tail -20 /tmp/lint-output.txt)"
fi

if [ -n "$ERRORS" ]; then
  # Вариант 1: JSON на stdout (exit 0) — более структурированный
  # Экранируем JSON-строку через jq для безопасности
  REASON=$(echo "$ERRORS" | jq -Rs .)
  echo "{\"decision\": \"block\", \"reason\": $REASON}"
  exit 0

  # Вариант 2 (альтернатива): exit 2 + stderr — проще, но менее структурированный
  # echo "$ERRORS" >&2
  # exit 2
fi

# Пустой stdout + exit 0 → субагент завершается нормально
exit 0
```

#### settings.json — hooks для режима Agent Teams

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": ".claude/hooks/lint-on-edit.sh"
          }
        ]
      }
    ],
    "TeammateIdle": [
      {
        "hooks": [
          {
            "type": "command",
            "command": ".claude/hooks/quality-gate-teammate.sh"
          }
        ]
      }
    ]
  }
}
```

#### .claude/hooks/quality-gate-teammate.sh

```bash
#!/bin/bash
# Запускается перед тем, как teammate уходит в idle (ТОЛЬКО Agent Teams).
# Exit code 2 + stderr → teammate получает ошибку и продолжает работу.
# Exit code 0 → teammate уходит в idle.

# 1. Build check
if ! npm run build > /tmp/build-output.txt 2>&1; then
  echo "BUILD FAILED. Fix before stopping:" >&2
  cat /tmp/build-output.txt | tail -20 >&2
  exit 2
fi

# 2. Tests check
if ! npm test > /tmp/test-output.txt 2>&1; then
  echo "TESTS FAILED. Fix before stopping:" >&2
  cat /tmp/test-output.txt | tail -30 >&2
  exit 2
fi

# 3. Lint check
if ! npm run lint > /tmp/lint-output.txt 2>&1; then
  echo "LINT FAILED. Fix before stopping:" >&2
  cat /tmp/lint-output.txt | tail -20 >&2
  exit 2
fi

echo "All quality gates passed ✓"
exit 0
```

#### .claude/hooks/lint-on-edit.sh

```bash
#!/bin/bash
# Запускается после каждого Edit/Write.
# Автоматически форматирует изменённый файл.

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

if [[ -z "$FILE_PATH" ]]; then
  exit 0
fi

# Prettier для JS/TS
if [[ "$FILE_PATH" =~ \.(js|ts|jsx|tsx)$ ]]; then
  npx prettier --write "$FILE_PATH" 2>/dev/null || true
fi

# gofmt для Go
if [[ "$FILE_PATH" =~ \.go$ ]]; then
  gofmt -w "$FILE_PATH" 2>/dev/null || true
fi

exit 0
```

---

### Agent Teams для сложных задач

Включение экспериментальной фичи — через `settings.json` (рекомендуется, сохраняется между сессиями):

```json
{
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  }
}
```

Или через переменную окружения (только для текущей сессии):

```bash
export CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1
```

Промт для Lead-агента с Agent Teams:

```
Create an agent team to implement phase 1 from docs/plan/{task}.md.

Spawn these teammates:
- "backend-dev": implements code from the plan phase
- "tester": writes tests and runs the build after backend-dev signals completion
- "arch-reviewer": reviews implementation against docs/design/{task}.md

Coordination rules:
- backend-dev works first
- backend-dev messages "implementation-complete" when done
- tester runs after backend-dev, messages "tests-passed" or "tests-failed with [details]"
- arch-reviewer runs after tester passes, produces final compliance report
- If any reviewer finds CRITICAL issues, route specific file:line back to backend-dev for fixes
```

---

## Файловая структура проекта

```
project-root/
├── CLAUDE.md                         # Контекст проекта + ссылки на стандарты
├── prompts/
│   ├── architecture.md               # Архитектурные паттерны команды
│   ├── domain-models.md              # Соглашения по доменным моделям
│   ├── testing.md                    # Стратегия тестирования
│   ├── naming.md                     # Соглашения по именованию
│   ├── security.md                   # Security checklist команды
│   └── api-contracts.md              # Правила API
├── docs/
│   ├── research/                     # Артефакты Research фазы
│   │   └── {task-name}.md
│   ├── design/                       # Артефакты Design фазы
│   │   └── {task-name}.md
│   └── plan/                         # Артефакты Planning фазы
│       └── {task-name}/
│           ├── phase-1.md
│           ├── phase-2.md
│           └── phase-3.md
├── .claude/
│   ├── agents/
│   │   ├── researcher-architecture.md
│   │   ├── researcher-domain.md
│   │   ├── researcher-integrations.md
│   │   ├── designer.md
│   │   ├── planner.md
│   │   ├── backend-developer.md
│   │   ├── tester.md
│   │   ├── arch-reviewer.md
│   │   ├── security-reviewer.md
│   │   └── plan-compliance.md
│   ├── commands/                     # Простые slash-команды (плоские .md файлы)
│   │   ├── research.md               # /research → запускает Research фазу
│   │   ├── design.md                 # /design → запускает Design фазу
│   │   ├── plan.md                   # /plan → запускает Planning фазу
│   │   └── implement.md              # /implement → запускает Implementation фазу
│   │
│   │   # Альтернатива: Skills с поддерживающими файлами (директория + SKILL.md)
│   ├── skills/
│   │   └── research/
│   │       ├── SKILL.md              # /research (главный файл)
│   │       └── examples/             # Примеры research-документов для Claude
│   ├── hooks/
│   │   ├── quality-gate.sh
│   │   └── lint-on-edit.sh
│   └── settings.json                 # Hooks конфигурация
```

---

## Slash-команды для каждой фазы

Есть два эквивалентных формата:

- **Простой** (slash command): `.claude/commands/research.md` — плоский markdown-файл с YAML frontmatter
- **Расширенный** (Skill): `.claude/skills/research/SKILL.md` + поддерживающие файлы (примеры, шаблоны, скрипты)

Оба создают `/research`. Используй Skills когда нужны примеры или шаблоны рядом с инструкцией. В остальных случаях — простые commands.

### .claude/commands/research.md

```markdown
---
name: research
description: Run Research phase for a task. Spawns parallel research subagents and produces a facts document.
---

# Research Phase

Run the Research phase for the given task.

Steps:
1. Ask the user: "What is the task? Provide ticket/description."
2. Decompose the task into research dimensions:
   - Architecture: overall structure, entry points, key modules
   - Domain models: entities, value objects, aggregates
   - External integrations: APIs, databases, third-party services
   - Tests: existing test coverage for related areas
3. Spawn a separate `researcher-*` subagent for each dimension IN PARALLEL
4. Each subagent gets: its specific dimension + relevant file patterns
5. Collect all results
6. Write merged facts to docs/research/{task-name}.md
7. Report: "Research complete. Facts document: docs/research/{task-name}.md"

The research document must contain ONLY facts with file:line references.
Zero opinions. Zero suggestions.
```

### .claude/commands/implement.md

```markdown
---
name: implement
description: Run Implementation phase for a specific plan phase.
---

# Implementation Phase

Run implementation for a specific phase of the plan.

Input required:
- Task name
- Phase number

Steps:
1. Read docs/plan/{task}/phase-{N}.md
2. Spawn `backend-developer` subagent to implement the phase
3. Wait for completion
4. Spawn `tester` subagent
5. Wait for completion
6. If tests pass: spawn `arch-reviewer` subagent
7. If tests fail: route failure details back to `backend-developer`
8. If arch-reviewer finds CRITICAL issues: route to `backend-developer` with specific file:line
9. Spawn `security-reviewer` subagent
10. Spawn `plan-compliance` subagent
11. Report: all gates status + any issues

Only proceed to next phase after ALL gates pass.
```

---

## CLAUDE.md: конфигурация проекта

```markdown
# Project: {Project Name}

## Stack
- Language: TypeScript / Go / Python (укажи свой)
- Framework: (укажи свой)
- Database: (укажи свой)

## Standards
Team standards are in prompts/:
- prompts/architecture.md — architectural patterns
- prompts/domain-models.md — domain model conventions
- prompts/testing.md — testing strategy
- prompts/naming.md — naming conventions
- prompts/security.md — security checklist

## Workflow
This project uses context engineering methodology (see methodology.md).
All AI agents must follow the 4-phase process:
1. Research → docs/research/
2. Design → docs/design/
3. Planning → docs/plan/
4. Implementation → use /implement skill

## Rules
- Research agents describe facts only — no opinions
- Design agent reads ALL files in prompts/ before generating design
- Implementation agents follow the plan strictly
- No agent writes code before Planning phase is complete and approved
```

---

## Сводная таблица: методология → Claude Code

| Фаза методологии | Инструмент Claude Code | Ключевые настройки |
|---|---|---|
| **Research: Lead декомпозирует задачу** | Slash command `/research` | `.claude/commands/research.md` |
| **Research: параллельные субагенты** | Custom Subagents | `.claude/agents/researcher-*.md`, `model: haiku`, `isolation: worktree` |
| **Research: выход — файл фактов** | Файловые артефакты | `docs/research/{task}.md` |
| **Design: читает стандарты команды** | Subagent + prompts/ folder | `.claude/agents/designer.md` читает все `prompts/*.md` |
| **Design: генерирует C4, ADR, контракты** | Custom Subagent | `docs/design/{task}.md` |
| **Design: человеческий гейт** | Ручная правка документа | Инженер правит `docs/design/{task}.md` напрямую |
| **Planning: разбивка по фазам** | Custom Subagent | `.claude/agents/planner.md` → `docs/plan/{task}/phase-N.md` |
| **Planning: человеческий гейт** | Ручная правка | Инженер правит план напрямую |
| **Implementation: Lead координирует** | Slash command `/implement` | Никогда не пишет код сам |
| **Implementation: Backend** | Custom Subagent | `.claude/agents/backend-developer.md` |
| **Implementation: Tester** | Custom Subagent | `.claude/agents/tester.md` |
| **Implementation: Arch Reviewer** | Custom Subagent | `.claude/agents/arch-reviewer.md` |
| **Implementation: Security Reviewer** | Custom Subagent | `.claude/agents/security-reviewer.md` |
| **Implementation: Plan Compliance** | Custom Subagent | `.claude/agents/plan-compliance.md`, `model: haiku` |
| **Quality Gates (Subagents)** | `SubagentStop` hook (`type: command` только!) | JSON `{"decision": "block", "reason": "..."}` или exit 2 + stderr |
| **Quality Gates (Agent Teams)** | `TeammateIdle` hook | exit 2 блокирует teammate |
| **Quality Gates: автоформатирование** | `PostToolUse` hook | matcher `Edit\|Write` → lint-on-edit.sh |
| **Параллельные сессии без конфликтов** | Git Worktrees | `claude --worktree` или `isolation: worktree` в subagent |
| **Сложная координация между агентами** | Agent Teams (experimental) | `settings.json` → `{"env": {"CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"}}` |
| **Лёгкая координация без Agent Teams** | tmux + state-файлы | Stop hook → tmux send-keys к координатору |
| **Async уведомления** | Async hooks | `"async": true` в hook — не блокирует агента |
| **Запуск субагента** | `SubagentStart` hook | Для логирования, трекинга начала работы |
| **Кастомный git worktree setup** | `WorktreeCreate` / `WorktreeRemove` hooks | Для non-git VCS или кастомной настройки веток |

---

## Важные нюансы

### Subagents vs Agent Teams

- **Subagents** — работают внутри одной сессии. Lead запускает их через Task tool. Они не общаются между собой — только репортят обратно Lead-агенту. Достаточно для большинства задач.
- **Agent Teams** — отдельные Claude Code процессы, могут общаться напрямую (через inbox-файлы или мессенджинг). Нужны только когда требуется настоящая параллельная работа с коммуникацией между агентами (например, тестировщик должен передать детали ошибки напрямую разработчику).

### Quality gate hooks: два разных механизма

**Для Subagents** — `SubagentStop` hook:
```json
// stdout — блокировать (exit 0 + JSON):
{
  "decision": "block",
  "reason": "BUILD FAILED: fix errors before stopping. Errors:\n..."
}
// stdout — разрешить: пустой stdout или {} (БЕЗ поля decision)
```

> ⚠️ Поля `"approve"` **НЕ существует** для Stop/SubagentStop. Чтобы разрешить — не возвращайте decision.
> ⚠️ Поле `"reason"` — для блокировки (передаётся Claude). Поле `"systemMessage"` — универсальное поле для всех hook-типов (показывает предупреждение юзеру). Оба существуют, разное назначение.
> ⚠️ Обязательно проверяйте `stop_hook_active` во входном JSON чтобы избежать бесконечных циклов.

**Альтернативный механизм** (проще): exit code `2` + stderr → блокирует, stderr передаётся Claude.

**Для Agent Teams** — `TeammateIdle` hook:
```bash
# exit 2 + stderr → teammate получает сообщение и продолжает работу
# exit 0 → teammate уходит в idle
```

`TeammateIdle` работает **только** в контексте Agent Teams. Применять его к обычным субагентам бессмысленно — он просто не будет срабатывать.

**Коды выхода для command-hooks (единый механизм для всех событий):**
- `exit 0` — успех, stdout парсится как JSON для структурного контроля
- `exit 2` — блокирующая ошибка, stderr передаётся обратно Claude
- любой другой — неблокирующая ошибка, stderr показывается юзеру, выполнение продолжается

**Приоритет механизмов контроля** (от высшего к низшему):
1. `"continue": false` в JSON — полная остановка Claude
2. `"decision": "block"` в JSON — блокировка конкретного действия
3. Exit code `2` — блокировка через stderr

**JSON-поля, доступные для ВСЕХ hook-типов (Universal Fields):**
```json
{
  "continue": true,         // false → Claude полностью останавливается
  "stopReason": "string",   // сообщение при continue:false (показывается юзеру, НЕ Claude)
  "suppressOutput": false,  // true → stdout скрыт из verbose mode output
  "systemMessage": "string" // предупреждение, показываемое юзеру (НЕ Claude)
}
```

**JSON-решения по типам событий:**

| Событие | Поля решения | Значения |
|---|---|---|
| `PreToolUse` | `hookSpecificOutput.permissionDecision` | `"allow"` / `"deny"` / `"ask"` |
| `PermissionRequest` | `hookSpecificOutput.decision.behavior` | `"allow"` / `"deny"` |
| `PostToolUse` | `decision` | `"block"` (feedback) / undefined |
| `Stop` / `SubagentStop` | `decision` | `"block"` / undefined |

Это детерминированный механизм: агент не может завершить фазу, пока не пройдут все quality gates. Не зависит от LLM.

### Изоляция контекстных окон

- Каждый субагент стартует с **чистым контекстом** — без истории текущей сессии
- Передача информации между фазами — только через **файлы** (Research doc → Design doc → Plan doc)
- Это центральный принцип методологии: "каждая фаза — новое контекстное окно"

### Стоимость токенов

- Research субагенты → `model: haiku` (дёшево, только чтение файлов)
- Design, Planning → `model: sonnet` (требует сложного мышления)
- Implementation Backend → `model: sonnet` или `opus` для сложного кода
- Plan Compliance → `model: haiku` (механическая проверка чеклиста)
- Security Reviewer → `model: opus` (критично не пропустить уязвимости)

---

---

## Дополнения и новые фичи (февраль 2026)

### Async Hooks (добавлены в январе 2026)

По умолчанию hooks синхронные — Claude ждёт их завершения. Async hooks запускаются без блокировки сессии:

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": ".claude/hooks/async-notify.sh",
            "async": true
          }
        ]
      }
    ]
  }
}
```

Используй async для: уведомлений, логирования, аналитики — всего, что не должно блокировать агента.

---

### Настройка hooks

Hooks настраиваются через `.claude/settings.json` (project-level) или `~/.claude/settings.json` (user-level). Интерфейс `/config` в TUI позволяет открыть файл настроек для редактирования.

---

### Agent Teams: паттерн Swarm через tmux

Кроме официального Agent Teams API, существует проверенный community-паттерн координации через tmux + state-файлы. Используется для более гибкой оркестрации:

**Структура state-файла агента** (`.claude/agent-state.local.md`):
```markdown
---
agent_name: backend-developer
task_number: 1
coordinator_session: lead-session
enabled: true
dependencies: []
---

# Task Assignment

Implement phase 1 from docs/plan/{task}/phase-1.md.
```

**Hook для нотификации координатора** (`.claude/hooks/notify-lead.sh`):
```bash
#!/bin/bash
# Stop hook — отправляет сигнал Lead-агенту через tmux когда субагент завершился

STATE_FILE=".claude/agent-state.local.md"
if [[ ! -f "$STATE_FILE" ]]; then
  exit 0
fi

COORDINATOR=$(grep '^coordinator_session:' "$STATE_FILE" | sed 's/coordinator_session: *//')
AGENT=$(grep '^agent_name:' "$STATE_FILE" | sed 's/agent_name: *//')
ENABLED=$(grep '^enabled:' "$STATE_FILE" | sed 's/enabled: *//')

if [[ "$ENABLED" != "true" ]]; then
  exit 0
fi

if tmux has-session -t "$COORDINATOR" 2>/dev/null; then
  tmux send-keys -t "$COORDINATOR" "Agent $AGENT completed." Enter
fi

exit 0
```

Это позволяет строить свободную координацию без экспериментального Agent Teams API. Подходит для production.

---

### Hooks в frontmatter субагента

Начиная с текущих версий, hooks можно определять прямо в frontmatter субагента (а не только в settings.json). Это позволяет упаковывать поведение субагента вместе с его hooks:

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

---

### Plugins (экосистема расширений)

Полноценная система плагинов для распространения конфигурации между проектами и командами.

**Структура плагина** (верифицировано по официальной документации):

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

**Установка плагинов:**
```bash
# CLI-установка
claude plugin install <plugin-name>

# Через интерактивное меню (в TUI)
/plugin  # → вкладка Discover → Add
```

**Маркетплейс:** 28+ официальных плагинов в `~/.claude/plugins/marketplaces/claude-plugins-official/plugins/`.

**Использование для методологии:** плагин может упаковать все agents/, hooks/, commands/ из методологии в один устанавливаемый пакет, распространяемый между проектами команды.

---

### Skills: детали системы (верифицировано)

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
| `allowed-tools` | нет | Инструменты без запроса разрешения при активном скилле (⚠️ баг — см. ниже) |
| `context` | нет | `"fork"` → запуск в изолированном subagent context |
| `agent` | нет | Какой субагент использовать при `context: fork` |
| `hooks` | нет | Lifecycle hooks, привязанные к скиллу |

> ⚠️ **Критический баг:** поле `allowed-tools` в frontmatter скиллов **ненадёжно** (Issue #14956). Не выдаёт разрешения на Bash-команды, которые должно разрешать. Для ограничения инструментов используйте **субагентов** (у них `tools` работает корректно).

**Слияние commands и skills:**
- `.claude/commands/research.md` и `.claude/skills/research/SKILL.md` — оба создают `/research`
- Существующие `.claude/commands/` файлы продолжают работать
- Skills добавляют: директорию для файлов, контроль invocation, авто-загрузку по описанию

---

### Sub-Agent Routing Rules в CLAUDE.md

Best practice из community — добавить в CLAUDE.md правила маршрутизации субагентов:

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

---

### Переменные окружения в hooks

**Официально задокументированные:**
- `$CLAUDE_PROJECT_DIR` — корневая директория проекта (для портабельных путей)
- `$CLAUDE_PLUGIN_ROOT` — корневая директория плагина (для plugin hooks)
- `$CLAUDE_ENV_FILE` — путь к файлу для персистентных env vars (только в `SessionStart` hooks)

**Получение tool input в hooks:**

Tool input передаётся через **JSON на stdin** (это официальный механизм). Переменные окружения вида `$CLAUDE_TOOL_INPUT_*` **не документированы** и не гарантированы — для Read/Glob они точно не работают (Issue #17637). Используйте парсинг stdin:

```bash
# В hook-скрипте: получение file_path из stdin
INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
```

Пример inline-хука для автоформатирования:
```json
{
  "type": "command",
  "command": ".claude/hooks/format-on-edit.sh"
}
```

---

### Agent SDK (программная оркестрация)

Помимо CLI, субагенты можно определять и запускать программно через Agent SDK:

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
- Кастомные MCP-инструменты через `createSdkMcpServer()`
- Резюмирование сессий через `resume: sessionId` (+ `forkSession`, `resumeSessionAt`)
- Детекция контекста субагента через `parent_tool_use_id` поле в SDK message types (`SDKAssistantMessage`, `SDKUserMessage`)

---

### Новые CLI-команды (v2.1.50-51)

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

---

### 5-уровневая иерархия settings

Настройки Claude Code работают в 5 скоупах (от высшего приоритета к низшему):

1. **Managed policy** (`managed-settings.json`) — корпоративные политики (самый высокий приоритет)
2. **CLI arguments** — аргументы командной строки (временные, для текущей сессии)
3. **`.claude/settings.local.json`** — локальные настройки проекта (не коммитятся в git)
4. **`.claude/settings.json`** — настройки проекта (коммитятся в git)
5. **`~/.claude/settings.json`** — пользовательские настройки (lowest)

> **Правило:** hooks из `.claude/settings.json` коммитятся в репозиторий и работают для всей команды. Для локальных экспериментов — `.claude/settings.local.json`.

---

---

## Известные баги и ограничения (критическое ревью, 24 февраля 2026)

> Раздел верифицирован по открытым issues в anthropics/claude-code. Актуально на дату документа.

### 🔴 Активные баги

#### [Issue #17927] Worktree path resolution bug
**Статус:** открыт (январь 2026), пометка stale

При запуске агента из git worktree относительные пути разрешаются в **main repo**, а не в worktree. Пример:
```bash
git worktree add /path/to/worktree -b my-branch
cd /path/to/worktree && claude "Edit parsers.py"
# → редактирует /main-repo/parsers.py вместо /worktree/parsers.py
```

**Влияние на методологию:** `isolation: worktree` у Research-субагентов может писать файлы артефактов в неправильное место.

**Обходной путь:** при использовании worktree всегда указывать абсолютные пути. В промтах субагентов заменить относительные пути на `$(pwd)/...`.

---

#### [Issue #27562] `--tmux --worktree` — Claude не стартует
**Статус:** открыт (22 февраля 2026, только что)

Комбинация `claude --tmux --worktree` создаёт worktree, но tmux-сессия немедленно завершается без запуска Claude.

**Влияние:** tmux-based swarm coordination pattern (через `tmux send-keys`) нельзя комбинировать с `--worktree` через CLI-флаг.

**Обходной путь:** использовать `isolation: worktree` в frontmatter субагента (это внутренний механизм CC, не CLI-флаг) — работает отдельно от `--tmux`.

---

#### [Issue #14956] `allowed-tools` в Skills ненадёжен

**Статус:** открыт

Поле `allowed-tools` в SKILL.md frontmatter не выдаёт разрешения на Bash-команды, которые должно разрешать. Связанный Issue #18837 (закрыт как дубликат #14956) описывал обратную проблему — `allowed-tools` не ограничивал доступ к неуказанным инструментам. В целом механизм ненадёжен в обоих направлениях.

**Влияние на методологию:** нельзя надёжно контролировать инструменты через Skills.

**Обходной путь:** использовать субагентов с `tools` / `disallowedTools` — у них ограничения работают корректно для built-in tools. Оркестрационные команды (`/research`, `/implement`) реализовывать как commands, а ограничение инструментов — на уровне субагентов.

---

#### [Issue #25589] `disallowedTools` не блокирует MCP-инструменты
**Статус:** открыт (февраль 2026)

`--disallowedTools` и `disallowedTools` в субагентах блокируют только built-in tools. MCP tools остаются доступны независимо от ограничений.

**Влияние на методологию:** security-reviewer или другие субагенты с ограниченными `tools` могут получить доступ к MCP-инструментам, которые не должны использовать.

**Обходной путь:** не подключать ненужные MCP-серверы к субагентам (не указывать `mcpServers` в frontmatter). Без явного подключения субагент не получит MCP-инструменты.

---

#### [Issue #20221] `type: "prompt"` SubagentStop hooks не блокируют завершение
**Статус:** открыт (январь 2026)

SubagentStop hooks с `type: "prompt"` корректно оценивают и отправляют feedback субагенту, но **не предотвращают его завершение**. Субагент всё равно останавливается.

**Влияние на методологию:** quality gates через prompt-хуки не работают как блокирующие гейты.

**Обходной путь:** для quality gates использовать **только** `type: "command"` с exit code 2 или JSON `{"decision": "block"}`.

---

#### [Issue #24754] Task list state leaks across worktrees
**Статус:** открыт (февраль 2026)

`TaskCreate`/`TodoWrite` state привязан к git repository (shared `.git` directory), а не к отдельному worktree. Все параллельные сессии в разных worktrees видят и модифицируют один task list.

**Влияние на методологию:** при `isolation: worktree` для параллельных Research-субагентов, их task lists будут конфликтовать.

**Обходной путь:** не полагаться на встроенные task lists для координации между worktree-субагентами. Использовать файловые артефакты вместо task system.

---

#### [Issue #27069] Skills/commands дублируются в worktrees
**Статус:** открыт (февраль 2026)

При использовании git worktrees, commands из `.claude/commands/` появляются дважды в списке `/skills` — из main worktree и из текущего.

**Влияние:** косметическая проблема, не блокирует работу, но может путать.

---

#### [Issue #27756] Infinite CPU loop при удалении `.claude/commands/`
**Статус:** открыт (февраль 2026)

Если агент удаляет директорию `.claude/commands/` при наличии дублирующихся slash commands из вложенных директорий, CLI входит в бесконечный CPU loop.

**Влияние:** критическая проблема стабильности. Не удалять `.claude/commands/` программно.

---

### 🟡 Ограничения экспериментальных фич

#### Agent Teams: known limitations (официальная документация)

Официально задокументированы ограничения:

- **Session resumption** — возобновление сессии Agent Team ненадёжно
- **Task coordination** — возможны race conditions при координации задач
- **Shutdown behavior** — медленное завершение teammates (ждут окончания текущего запроса/tool-вызова)
- **Lead does work itself** — без Delegate Mode lead часто сам пишет код вместо делегирования

**Delegate Mode:** Ограничивает Lead координацией, запрещая прямое написание кода. Это напрямую соответствует методологии ("Lead никогда не пишет код сам"). Keybinding для активации (`Shift+Tab`) упоминается в community-источниках (claudefast.com), но **не подтверждён** официальной документацией Anthropic. В официальных docs рекомендуется указывать в промте: "Wait for your teammates to complete their tasks before proceeding."

**Best practices для Agent Teams:**

- Давать каждому teammate **явные файловые границы** в spawn-промте
- Использовать Delegate Mode по умолчанию
- Agent Teams потребляют **значительно больше токенов** чем одна сессия (каждый teammate — отдельный Claude-инстанс)
- Nicholas Carlini (Anthropic) построил C-компилятор с 16 агентами: 100K строк Rust, ~$20K API costs, ~2000 сессий. ⚠️ Использовал **кастомную оркестрацию** (Docker + git-based task locking), а не встроенный Agent Teams API

**Вывод:** Agent Teams не готовы для production-использования с жёсткими quality gates. Для надёжной реализации методологии предпочесть **Subagents + `SubagentStop` hook** вместо Agent Teams + `TeammateIdle`.

---

#### `isolation: worktree` в frontmatter — новая фича

Добавлена недавно. Вероятны неотловленные edge cases (см. баги worktree-экосистемы ниже). Использовать осторожно в первых реализациях.

---

### 🟢 Новое в последних релизах

- **`claude agents`** — CLI-команда для просмотра всех настроенных агентов. Полезно для отладки.
- **`claude --remote`** / **`claude --teleport`** — создание и возобновление web-сессий на claude.ai. Потенциально полезно для orchestration.

---

### Рекомендации по реализации с учётом рисков

| Фаза | Риск | Рекомендация |
| --- | --- | --- |
| Research (isolation: worktree) | Path resolution bug (#17927) | Использовать абсолютные пути в промтах субагентов |
| Research (isolation: worktree) | Task list leak (#24754) | Не полагаться на встроенные task lists; использовать файловые артефакты |
| Research (isolation: worktree) | Commands duplication (#27069) | Косметическая проблема, не критично |
| Implementation (Agent Teams) | Experimental, known limitations | Использовать Subagents + SubagentStop вместо Agent Teams для начала |
| Coordination (tmux + --worktree) | --tmux --worktree bug (#27562) | Не комбинировать --tmux и --worktree через CLI |
| Quality gates (SubagentStop) | prompt/agent hooks не блокируют (#20221) | Использовать **только** `type: "command"` для quality gates |
| Quality gates | — | SubagentStop надёжнее TeammateIdle для текущего состояния |
| Subagent tools/disallowedTools | Не блокирует MCP tools (#25589) | Не подключать ненужные mcpServers к субагентам |
| Skills allowed-tools | Не enforce-ится (#14956) | Ограничивать инструменты через subagent `tools`, не через skills |

---

## Следующие шаги

### Минимальная жизнеспособная реализация (MVP)

1. **Создать `.claude/agents/`** — субагенты для всех ролей (researcher-*, designer, planner, backend-developer, tester, arch-reviewer, security-reviewer, plan-compliance)
2. **Написать `prompts/`** — стандарты команды под конкретный проект (architecture.md, domain-models.md, testing.md, naming.md, security.md, api-contracts.md)
3. **Настроить `CLAUDE.md`** — описание проекта + ссылки на стандарты + Sub-Agent Routing Rules
4. **Создать `.claude/commands/`** — slash-команды для фаз (`/research`, `/design`, `/plan`, `/implement`)
5. **Настроить hooks в `.claude/settings.json`** — PostToolUse (lint-on-edit) + SubagentStop (quality gate)
6. **Создать `docs/` структуру** — research/, design/, plan/ для артефактов фаз
7. **Протестировать на реальном тикете**

### Принципы реализации

- **Начать с Subagents-only** (без Agent Teams) — надёжнее, проверено community
- **Использовать exit code 2 + stderr** для quality gates — проще чем JSON, работает надёжно
- **Только `type: "command"` для SubagentStop quality gates** — prompt/agent хуки не блокируют завершение (#20221)
- **Не использовать `allowed-tools` в Skills** — баг, не enforce-ится. Ограничения — только через subagent `tools`
- **Не подключать лишние `mcpServers` к субагентам** — `disallowedTools` не блокирует MCP tools (#25589)
- **Абсолютные пути в промтах субагентов** — обход бага worktree path resolution (#17927)
- **`stop_hook_active` проверка** в Stop/SubagentStop hooks — предотвращает бесконечные циклы
- **Не комбинировать `--tmux` и `--worktree`** через CLI (#27562)
- **Файловые артефакты вместо task lists** при работе с worktrees — task state leaks (#24754)

### Продвинутые возможности (после MVP)

- **Plugin** — упаковать всё в plugin для переиспользования между проектами
- **Agent Teams + Delegate Mode** — когда стабилизируется
- **`claude --remote` / `--teleport`** — для внешней orchestration
- **Agent SDK** — программная оркестрация для CI/CD интеграции
- **`PreCompact` hook** — backup transcript перед компакцией контекста
