# Реализация методологии контекстной инженерии в Claude Code

## Источники

- [Официальная документация subagents](https://code.claude.com/docs/en/sub-agents)
- [Agent Teams](https://code.claude.com/docs/en/agent-teams)
- [Hooks reference](https://code.claude.com/docs/en/hooks)
- [Hooks guide](https://code.claude.com/docs/en/hooks-guide)
- [Skills](https://code.claude.com/docs/en/skills)
- [Git Worktrees в Claude Code](https://notes.muthu.co/2026/02/the-complete-guide-to-git-worktrees-with-claude-code/)
- [Swarm Orchestration Skill](https://gist.github.com/kieranklaassen/4f2aba89594a4aea4ad64d753984b2ea)
- [Claude Code Hooks Complete Guide Feb 2026](https://smartscope.blog/en/generative-ai/claude/claude-code-hooks-guide/)
- [Agent Teams Guide](https://claudefa.st/blog/guide/agents/agent-teams)

> Документ верифицирован по версии **v2.1.50** (21 февраля 2026). Все примеры проверены против официальной документации.

---

## Ключевые примитивы Claude Code

| Примитив | Что это | Где живёт |
|---|---|---|
| **CLAUDE.md** | Всегда загружается в начало каждой сессии. Глобальный контекст проекта. | `./CLAUDE.md`, `~/.claude/CLAUDE.md` |
| **Subagent** | Изолированный Claude-инстанс со своим контекстным окном, своими инструментами и системным промтом. Запускается внутри сессии. | `.claude/agents/*.md` или `~/.claude/agents/*.md` |
| **Agent Teams** | Несколько независимых Claude Code сессий, работающих параллельно. Могут общаться между собой. Экспериментальная фича. | Через `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` |
| **Skill** | Инструкции + исполняемые команды, загружаемые по необходимости. Вызываются через `/skill-name`. | `.claude/skills/{name}/SKILL.md` (или упрощённо: `.claude/commands/{name}.md`) |
| **Hook** | Shell-команда, выполняемая детерминированно в конкретный момент жизненного цикла агента. | `.claude/settings.json` или `~/.claude/settings.json` |
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

Все поля frontmatter:

| Поле | Обязательное | Значения | Описание |
|---|---|---|---|
| `name` | да | строка | Идентификатор субагента |
| `description` | да | строка + `<example>` блоки | По этому полю Claude решает, когда делегировать задачу |
| `model` | нет | `haiku`, `sonnet`, `opus`, `inherit` | `inherit` — наследует от родителя |
| `tools` | нет | массив или строка через запятую | Ограничивает доступные инструменты |
| `color` | нет | `blue`, `green`, `yellow`, `red`, `purple` | Цвет в UI для визуального различия |
| `isolation` | нет | `worktree` | Запускает субагента в изолированном git worktree (добавлено в v2.1.50) |

> **Важно про `description`:** Claude использует это поле для автоматического делегирования. Чем конкретнее описание, тем точнее срабатывает делегирование. Официально рекомендуется добавлять `<example>` блоки.

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
# В frontmatter субагента (добавлено в v2.1.50, февраль 2026)
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

> **Важно: два разных механизма блокировки в зависимости от режима работы:**
> - **Subagents** → `SubagentStop` hook, возвращает JSON `{"decision": "block", "reason": "..."}` в stdout
> - **Agent Teams** → `TeammateIdle` hook, exit code `2` в stderr блокирует teammate

#### Полный список hook-событий (v2.1.50, 14+ событий)

| Событие | Когда срабатывает | Может блокировать |
|---|---|---|
| `SessionStart` | При старте/возобновлении сессии | Да |
| `SessionEnd` | При завершении сессии | Нет |
| `UserPromptSubmit` | При отправке промта, до обработки Claude | Да |
| `PreToolUse` | Перед выполнением tool-вызова | Да |
| `PermissionRequest` | При появлении диалога разрешения | Да |
| `PostToolUse` | После успешного tool-вызова | Нет |
| `PostToolUseFailure` | После неудачного tool-вызова | Нет |
| `Notification` | Когда Claude Code отправляет уведомление | Нет |
| `SubagentStart` | При запуске субагента | Нет |
| `SubagentStop` | При завершении субагента | Да (JSON output) |
| `Stop` | Когда Claude завершает ответ | Да (JSON output) |
| `TeammateIdle` | Когда teammate в Agent Teams уходит в idle | Да (exit 2) |
| `TaskCompleted` | Когда задача помечается как завершённая | Да |
| `ConfigChange` | При изменении конфига во время сессии | Нет |
| `WorktreeCreate` | При создании worktree через `--worktree` / `isolation: worktree` | Да (заменяет git) |
| `WorktreeRemove` | При удалении worktree | Нет |

#### Типы hook-обработчиков (три варианта)

```json
// 1. command — shell-команда (основной вариант)
{ "type": "command", "command": ".claude/hooks/my-script.sh" }

// 2. prompt — LLM-оценка (для нетривиальных решений)
{ "type": "prompt", "prompt": "Проверь что тесты написаны для всех публичных методов. Если нет — block." }

// 3. agent — запускает субагента (для сложных проверок)
{ "type": "agent", "agent": "quality-gate-agent" }
```

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

> ⚠️ **Критически важно:** решение `"approve"`, не `"allow"`. Официальный формат: `{"decision": "approve|block", "reason": "...", "systemMessage": "..."}`.
> Поле `systemMessage` — опциональный дополнительный контекст для Claude при блокировке.

```bash
#!/bin/bash
# Запускается когда субагент завершает работу (SubagentStop hook).
# Возвращает JSON {"decision": "block", "reason": "..."} → субагент не останавливается.
# Возвращает JSON {"decision": "approve"} или пустой stdout → субагент завершается.

ERRORS=""

# 1. Build check
if ! npm run build > /tmp/build-output.txt 2>&1; then
  ERRORS="BUILD FAILED:\n$(tail -20 /tmp/build-output.txt)"
fi

# 2. Tests check
if [ -z "$ERRORS" ] && ! npm test > /tmp/test-output.txt 2>&1; then
  ERRORS="TESTS FAILED:\n$(tail -30 /tmp/test-output.txt)"
fi

# 3. Lint check
if [ -z "$ERRORS" ] && ! npm run lint > /tmp/lint-output.txt 2>&1; then
  ERRORS="LINT FAILED:\n$(tail -20 /tmp/lint-output.txt)"
fi

if [ -n "$ERRORS" ]; then
  echo "{\"decision\": \"block\", \"reason\": \"Quality gate failed. Fix before stopping.\", \"systemMessage\": \"$ERRORS\"}"
  exit 0
fi

echo "{\"decision\": \"approve\"}"
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
| **Quality Gates (Subagents)** | `SubagentStop` hook | JSON `{"decision": "block", "systemMessage": "..."}` блокирует субагент |
| **Quality Gates (Agent Teams)** | `TeammateIdle` hook | exit 2 блокирует teammate |
| **Quality Gates: автоформатирование** | `PostToolUse` hook | matcher `Edit\|Write` → lint-on-edit.sh |
| **Параллельные сессии без конфликтов** | Git Worktrees | `claude --worktree` или `isolation: worktree` в subagent (v2.1.50+) |
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
// stdout — блокировать:
{
  "decision": "block",
  "reason": "BUILD FAILED: fix errors before stopping",
  "systemMessage": "<детали ошибок для Claude>"
}
// или разрешить:
{"decision": "approve"}
```

> ⚠️ Правильное значение — `"approve"`, не `"allow"`. `systemMessage` — опциональный контекст, который Claude получит при блокировке.

**Для Agent Teams** — `TeammateIdle` hook:
```bash
# exit 2 + stderr → teammate получает сообщение и продолжает работу
# exit 0 → teammate уходит в idle
```

`TeammateIdle` работает **только** в контексте Agent Teams. Применять его к обычным субагентам бессмысленно — он просто не будет срабатывать.

**Коды выхода для command-hooks:**
- `exit 0` — успех, stdout идёт в transcript
- `exit 2` — блокирующая ошибка, stderr передаётся обратно Claude
- любой другой — небокирующая ошибка, выполнение продолжается

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

### /hooks — интерактивное меню

В Claude Code появилось интерактивное меню для настройки hooks без ручного редактирования JSON:

```
/hooks
```

Показывает все доступные события, matchers и текущие hook-команды. Удобно для начальной настройки.

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

Помимо `.claude/agents/` и `.claude/skills/`, в 2026 появилась полноценная система плагинов:

```
.claude/plugins/
  my-plugin/
    plugin.json       # манифест
    agents/           # агенты плагина
    skills/           # skills плагина
    hooks/            # hooks плагина
    mcp/              # MCP серверы
```

Плагины можно устанавливать из маркетплейса (`/plugins`) или из локальных директорий. Это способ переиспользовать `.claude/` конфигурацию между проектами.

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

### 🟡 Ограничения экспериментальных фич

#### Agent Teams: known limitations (официальная документация)
Официально задокументированы ограничения:
- **Session resumption** — возобновление сессии Agent Team ненадёжно
- **Task coordination** — возможны race conditions при координации задач
- **Shutdown behavior** — неконтролируемое завершение teammates

**Вывод:** Agent Teams не готовы для production-использования с жёсткими quality gates. Для надёжной реализации методологии предпочесть **Subagents + `SubagentStop` hook** вместо Agent Teams + `TeammateIdle`.

---

#### `isolation: worktree` в frontmatter — новая фича (v2.1.50, 20 февраля 2026)
Добавлена 4 дня назад. Вероятны неотловленные edge cases. Использовать осторожно в первых реализациях.

---

### 🟢 Новое в v2.1.51 (последний релиз на момент ревью)

- **`claude remote-control`** — новый subcommand для внешнего управления сессиями Claude Code. Потенциально полезен для orchestration в swarm-паттернах как альтернатива tmux.
- **`claude agents`** — CLI-команда для просмотра всех настроенных агентов (добавлено в v2.1.50). Полезно для отладки.

---

### Рекомендации по реализации с учётом рисков

| Фаза | Риск | Рекомендация |
|---|---|---|
| Research (isolation: worktree) | Path resolution bug | Использовать абсолютные пути в промтах субагентов |
| Implementation (Agent Teams) | Experimental, known limitations | Использовать Subagents + SubagentStop вместо Agent Teams для начала |
| Coordination (tmux + --worktree) | --tmux --worktree bug | Не комбинировать --tmux и --worktree через CLI |
| Quality gates | — | SubagentStop надёжнее TeammateIdle для текущего состояния |

---

## Следующие шаги

1. Создать структуру `.claude/agents/` с файлами субагентов
2. Написать `prompts/` — стандарты команды под конкретный проект
3. Настроить `CLAUDE.md` с описанием проекта и ссылками на стандарты
4. Настроить hooks в `.claude/settings.json`
5. Создать `docs/` структуру для артефактов фаз
6. Протестировать на реальном тикете
7. **Начать с Subagents-only** (без Agent Teams) — надёжнее для начального внедрения
8. **Мониторить Issue #17927** (worktree path bug) перед активным использованием `isolation: worktree`
