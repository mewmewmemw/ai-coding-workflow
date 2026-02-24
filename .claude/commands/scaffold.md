# Autonomous .claude/ scaffold generator

Сгенерируй полную `.claude/` конфигурацию для проекта. Работай автономно — анализируй, не спрашивай.

## Phase 1: Load knowledge

Прочитай research-файлы — это твоя база знаний о текущем состоянии Claude Code:

1. `research-cc-primitives-reference.md` — все доступные примитивы (frontmatter поля, hooks, skills, settings, CLI)
2. `research-cc-known-issues.md` — известные баги. **Обязательно**: прочитай секцию "Принципы реализации" и извлеки **каждый** guardrail. Каждый сгенерированный файл MUST comply
3. `research-claude-code-implementation.md` — проверенные паттерны реализации, таблица "Рекомендации по реализации с учётом рисков"

## Phase 2: Analyze project

Проанализируй целевой проект (аргумент $ARGUMENTS, или текущая директория):

- Структура файлов и директорий
- Языки, фреймворки, зависимости (package.json, pyproject.toml, go.mod, Cargo.toml, Makefile, etc.)
- README.md — назначение и scope проекта
- Существующий `.claude/` — что есть, что работает, что устарело
- Существующий `CLAUDE.md` — текущие инструкции
- Тесты, CI/CD, деплой
- Какие задачи разработки нужны проекту (code review, тестирование, документация, рефакторинг, и т.д.)

## Phase 3: Extract guardrails

Из "Принципы реализации" и "Рекомендации по реализации" в known-issues извлеки полный список guardrails. Каждый guardrail — это конкретное правило генерации. Примеры (не хардкод — **извлеки актуальные из файла**):

- maxTurns обязателен в каждом агенте
- tools: (не allowed-tools:) в agent frontmatter
- type: "command" для всех hooks
- и т.д. — всё что найдёшь в "Принципы реализации"

Покажи список извлечённых guardrails перед продолжением.

## Phase 4: Design

На основе knowledge + analysis + guardrails, спроектируй полную `.claude/` структуру:

### CLAUDE.md
- Описание проекта и назначение
- Таблица ключевых файлов
- Доступные команды (/)
- Стандарты кода и конвенции (из анализа проекта)
- Guardrails из known-issues
- Маршрутизация субагентов (что параллельно, что последовательно, лимиты)

### agents/*.md
Для каждой задачи проекта — субагент с frontmatter:
- name, description (en), model, tools, maxTurns (ОБЯЗАТЕЛЬНО)
- model: haiku для read-only/research, sonnet для сложных задач, inherit по умолчанию
- tools: для ограничений (НИКОГДА allowed-tools:)
- Если isolation: worktree — добавь WorktreeCreate hook для копирования .claude/ поддиректорий

### commands/*.md
Для каждого пользовательского workflow:
- Пошаговые инструкции
- Approval gates для деструктивных операций
- ОБЯЗАТЕЛЬНО включи commands/scaffold.md (саморефренция)

### settings.json
- Правила разрешений
- Hooks (только type: "command")
- MCP-серверы если нужно (минимизировать)

### hooks/
- Shell-скрипты
- git rev-parse --show-toplevel (НЕ $CLAUDE_PROJECT_DIR)
- exit 0 при успехе, exit 2 при блокирующей ошибке

## Phase 5: Present plan

Покажи:

1. Дерево файлов
2. Таблица агентов: name | model | maxTurns | role
3. Таблица команд: name | что делает
4. Список применённых guardrails (с номерами issues)
5. Diff с существующим .claude/ (если есть)

**Жди одобрения перед генерацией.**

## Phase 6: Generate

После одобрения — запиши все файлы.

## Phase 7: Validate

Проверь compliance каждого сгенерированного файла с КАЖДЫМ guardrail из Phase 3.
Формат: `[PASS/FAIL]` для каждой проверки.
Если FAIL — исправь и перепроверь.

## Rules

- **Автономность**: анализируй проект, не задавай вопросов. Всё выводи из структуры.
- **Research-driven**: каждое решение основано на research-файлах. Не полагайся на training data.
- **Guardrails first**: compliance с known-issues не обсуждается.
- **Self-referential**: сгенерированный .claude/ ДОЛЖЕН включать /scaffold.
- **Язык**: если документация проекта на русском — генерируй на русском. Agent descriptions — на английском.
- **Re-scaffold**: если .claude/ уже существует — покажи что изменится, не перезаписывай слепо.
