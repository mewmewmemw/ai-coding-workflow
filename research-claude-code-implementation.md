# Реализация методологии контекстной инженерии в Claude Code

> Companion-документы:
> - Справочник по примитивам — `research-cc-primitives-reference.md`
> - Известные баги и ограничения — `research-cc-known-issues.md`

> Документ верифицирован по версии **v2.1.50-51** (февраль 2026). Непрерывная верификация: exa + context7 + GitHub issues + WebFetch official docs, параллельные агенты верификации.

---

## Источники

### Официальная документация
- [Subagents](https://code.claude.com/docs/en/sub-agents)
- [Agent Teams](https://code.claude.com/docs/en/agent-teams)
- [Hooks reference](https://code.claude.com/docs/en/hooks)
- [Hooks guide](https://code.claude.com/docs/en/hooks-guide)
- [Skills](https://code.claude.com/docs/en/skills)
- [Plugins reference](https://code.claude.com/docs/en/plugins-reference)
- [Settings reference](https://code.claude.com/docs/en/settings)
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

---

## Ключевые примитивы Claude Code

| Примитив | Что это | Где живёт |
|---|---|---|
| **CLAUDE.md** | Всегда загружается в начало каждой сессии. Глобальный контекст проекта. | `./CLAUDE.md`, `~/.claude/CLAUDE.md` |
| **Subagent** | Изолированный Claude-инстанс со своим контекстным окном, инструментами и системным промтом. | `.claude/agents/*.md` или `~/.claude/agents/*.md` |
| **Agent Teams** | Несколько независимых Claude Code сессий, работающих параллельно. Экспериментальная фича. | Через `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` |
| **Skill** | Инструкции + команды, загружаемые по необходимости через `/skill-name`. | `.claude/skills/{name}/SKILL.md` или `.claude/commands/{name}.md` |
| **Hook** | Shell-команда, выполняемая детерминированно в конкретный момент жизненного цикла агента. | `.claude/settings.json` или `~/.claude/settings.json` |
| **Plugin** | Пакет для распространения agents + skills + hooks + MCP серверов между проектами. | `.claude-plugin/plugin.json` + компоненты в корне плагина |
| **Git Worktree** | Изолированная копия репозитория. Позволяет субагентам работать параллельно. | `claude --worktree` или `isolation: worktree` в subagent |

> Полный справочник по каждому примитиву (frontmatter, hooks, JSON-формат, настройки) — см. `research-cc-primitives-reference.md`.
> Известные баги, обходные пути и рекомендации — см. `research-cc-known-issues.md`.

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

> Полная таблица frontmatter полей (13 documented + `color`) — см. `research-cc-primitives-reference.md` → Subagents.

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

> ⚠️ **Ограничение параллелизма:** запуск большого числа параллельных субагентов может вызвать JavaScript heap OOM (Issue #19100), context overflow (Issue #23463) или compaction cascade (Issue #27794). Рекомендуется ограничивать до 2-3 параллельных субагентов. `model: haiku` снижает memory footprint. Использовать файловые артефакты для больших результатов.

### Git Worktrees для изоляции

```yaml
# В frontmatter субагента
isolation: worktree
```

Это даёт каждому субагенту изолированную копию репозитория — важно при параллельном чтении больших кодовых баз. При использовании `isolation: worktree` автоматически срабатывают hook-события `WorktreeCreate` и `WorktreeRemove`.

> ⚠️ При использовании worktree учитывайте известные баги (path resolution, task list leaks) — см. `research-cc-known-issues.md`.

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

Hooks обеспечивают детерминированный контроль — агент не может их обойти (с оговорками — см. ниже).

> **Механизмы блокировки:**
> - **Subagents** → `SubagentStop` hook: exit code `2` + stderr или JSON `{"decision": "block", "reason": "..."}`
> - **Agent Teams** → `TeammateIdle` hook: exit code `2` + stderr
> - **Основной агент** → `Stop` hook: аналогично `SubagentStop`
>
> Полный список 17 hook-событий, JSON-формат, handler types — см. `research-cc-primitives-reference.md` → Hooks.
>
> ⚠️ **КРИТИЧНО:** Используйте **только `type: "command"`** для quality gates. `type: "prompt"` и `type: "agent"` для SubagentStop **не блокируют завершение** (Issue #20221). SubagentStop hooks ненадёжны даже с `type: command` (~42% failure rate, Issue #27755). **CI — обязательный fallback.** Подробнее — см. `research-cc-known-issues.md`.
>
> ⚠️ **[SECURITY]** `PreToolUse` hooks **полностью обходятся субагентами** (Issue #21460). Не полагайтесь на PreToolUse как security boundary при использовании субагентов. Ограничивайте tools через frontmatter `tools`/`disallowedTools`.

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

> **Формат JSON для Stop/SubagentStop:**
> - Блокировать: `{"decision": "block", "reason": "описание проблемы"}` — `reason` обязателен, передаётся Claude
> - Разрешить: пустой stdout или `{}` (без поля `decision`)
> - Альтернатива: exit code `2` + stderr → тоже блокирует
>
> Полная таблица JSON-решений по типам событий — см. `research-cc-primitives-reference.md` → Hooks → JSON-решения.

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
  # JSON на stdout (exit 0) — более структурированный
  REASON=$(echo "$ERRORS" | jq -Rs .)
  echo "{\"decision\": \"block\", \"reason\": $REASON}"
  exit 0

  # Альтернатива: exit 2 + stderr — проще
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

#### Hooks в frontmatter субагента

Hooks можно определять прямо в frontmatter субагента (а не только в settings.json):

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

### Agent Teams для сложных задач

> Подробности, ограничения и best practices — см. `research-cc-primitives-reference.md` → Agent Teams и `research-cc-known-issues.md` → Ограничения экспериментальных фич.

Включение через `settings.json` (рекомендуется):

```json
{
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  }
}
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

### Паттерн Swarm через tmux (без Agent Teams)

Проверенный community-паттерн координации через tmux + state-файлы. Подходит для production.

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
│   ├── commands/                     # Slash-команды для фаз
│   │   ├── research.md               # /research
│   │   ├── design.md                 # /design
│   │   ├── plan.md                   # /plan
│   │   └── implement.md              # /implement
│   ├── hooks/
│   │   ├── quality-gate-subagent.sh
│   │   ├── quality-gate-teammate.sh
│   │   └── lint-on-edit.sh
│   └── settings.json                 # Hooks конфигурация
```

---

## Slash-команды для каждой фазы

Два эквивалентных формата:

- **Простой** (slash command): `.claude/commands/research.md` — плоский markdown с YAML frontmatter
- **Расширенный** (Skill): `.claude/skills/research/SKILL.md` + поддерживающие файлы

Оба создают `/research`. Используй Skills когда нужны примеры или шаблоны рядом с инструкцией.

> Полный справочник Skills (frontmatter, progressive disclosure, ограничения) — см. `research-cc-primitives-reference.md` → Skills.

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
| **Quality Gates (Subagents)** | `SubagentStop` hook (`type: command` только!) | ⚠️ Ненадёжно (#27755), CI — обязательный fallback |
| **Quality Gates (Agent Teams)** | `TeammateIdle` hook | exit 2 блокирует teammate |
| **Quality Gates (CI fallback)** | CI pipeline | Последний рубеж: линтеры, тесты, security-проверки |
| **Quality Gates: автоформатирование** | `PostToolUse` hook | matcher `Edit\|Write` → lint-on-edit.sh |
| **Параллельные сессии** | Git Worktrees | `isolation: worktree` в subagent |
| **Сложная координация** | Agent Teams (experimental) | `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` |
| **Координация без Agent Teams** | tmux + state-файлы | Stop hook → tmux send-keys |

---

## Важные нюансы

### Subagents vs Agent Teams

- **Subagents** — работают внутри одной сессии. Lead запускает их через Task tool. Не общаются между собой — только репортят Lead-агенту. Достаточно для большинства задач.
- **Agent Teams** — отдельные Claude Code процессы, могут общаться через Mailbox-систему. Нужны только для настоящей параллельной работы с inter-agent коммуникацией. ⚠️ Экспериментальная фича с известными ограничениями — см. `research-cc-known-issues.md`.

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

## CI Pipeline: обязательный fallback для quality gates

SubagentStop hooks ненадёжны (~42% failure rate, Issue #27755). CI pipeline — **единственный гарантированный** quality gate.

### Пример GitHub Actions workflow

```yaml
# .github/workflows/quality-gates.yml
name: Quality Gates

on:
  pull_request:
    branches: [main]

jobs:
  quality:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup
        uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'

      - run: npm ci

      - name: Build
        run: npm run build

      - name: Tests
        run: npm test

      - name: Lint
        run: npm run lint

      - name: Security audit
        run: npm audit --audit-level=high
```

> Этот pipeline дублирует все проверки из `quality-gate-subagent.sh`. Даже если SubagentStop hook не сработал в ~42% случаев — CI поймает проблему до merge.

---

## Следующие шаги

### Минимальная жизнеспособная реализация (MVP)

1. **Создать `.claude/agents/`** — субагенты для всех ролей
2. **Написать `prompts/`** — стандарты команды под конкретный проект
3. **Настроить `CLAUDE.md`** — описание проекта + ссылки на стандарты
4. **Создать `.claude/commands/`** — slash-команды для фаз (`/research`, `/design`, `/plan`, `/implement`)
5. **Настроить hooks в `.claude/settings.json`** — PostToolUse (lint-on-edit) + SubagentStop (quality gate)
6. **Настроить CI pipeline** — обязательный fallback для quality gates (см. ниже)
7. **Создать `docs/` структуру** — research/, design/, plan/ для артефактов фаз
8. **Протестировать на реальном тикете**

> Принципы реализации с учётом известных багов — см. `research-cc-known-issues.md` → Принципы реализации.

### Продвинутые возможности (после MVP)

- **Plugin** — упаковать всё в plugin для переиспользования между проектами
- **Agent Teams** — когда стабилизируется. Lead ограничивается координацией через промт "Wait for your teammates to complete their tasks before proceeding" (Delegate Mode — community-термин, промптинг-паттерн, не формальный режим)
- **`claude --remote` / `--teleport`** — для внешней orchestration
- **`PreCompact` hook** — backup transcript перед компакцией контекста
- **CI-интеграция через `claude -p`** — программный запуск агентов в CI pipeline
