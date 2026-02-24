# ai-coding-workflow

Самоподдерживающийся конструктор `.claude/` конфигураций. Работает на собственном выходе: research-файлы информируют генератор, генератор создаёт `.claude/`, `.claude/` поддерживает research-файлы.

## Ключевые файлы

| Файл | Содержание |
|---|---|
| `methodology.md` | Методология (4 фазы: Research -> Design -> Planning -> Implementation) |
| `research-cc-primitives-reference.md` | Справочник примитивов Claude Code (frontmatter, hooks, skills, plugins, settings, CLI, agent teams) |
| `research-cc-known-issues.md` | Известные баги (55 issues, 53 open, 2 closed) |
| `research-claude-code-implementation.md` | Маппинг методологии на примитивы Claude Code |

## Команды

- `/scaffold` -- автономная генерация `.claude/` конфигурации на основе research-файлов. Читает research → анализирует проект → извлекает guardrails → генерирует. Саморефрентная: генерирует в том числе себя
- `/audit` -- критическое ревью документации (параллельные агенты верификации → сведение → валидация → применение)
- `/update` -- обновление после нового релиза CC (changelog → выявление изменений → применение)
- `/add-primitive` -- добавление нового примитива (research → design → plan → implement)
- `/check-issues` -- быстрая проверка статуса issues через `gh` CLI

## Guardrails (из research-cc-known-issues.md)

Эти правила ОБЯЗАТЕЛЬНЫ при любой генерации или модификации `.claude/` файлов:

- **maxTurns** в каждом субагенте (#28148: без лимита — 153GB output)
- **`tools:`** в agent frontmatter, НИКОГДА `allowed-tools:` (#27099: молча игнорируется, субагент наследует всё)
- **`type: "command"`** для всех hooks (#17249, #20221: prompt/agent хуки опасны)
- **`git rev-parse --show-toplevel`** в hook-скриптах, НЕ `$CLAUDE_PROJECT_DIR` (#27343)
- **Не более 2-3 параллельных субагентов** (#19100: OOM при 4GB heap, #27794: compaction cascade)
- **Файловые артефакты** вместо возвращаемых данных (#23463: overflow context)
- **Минимизировать `mcpServers`** у субагентов (#25589, #28126: duplication + leak)

## Правила

- **Scope:** только Claude Code CLI. Agent SDK (TS/Python) -- OUT OF SCOPE
- **Язык:** документация на русском, описания агентов (frontmatter descriptions) на английском
- **Факты, не мнения:** в research-файлах только факты. Без оценок, советов, рекомендаций
- **Issues:** каждый issue содержит: статус, описание, влияние, обходной путь
- **MEMORY.md:** обновлять после каждого значимого изменения
- **Поиск:** всегда `mcp__exa__web_search_exa` вместо WebSearch
- **Не доверяй training data** -- всегда загружай official docs

## Маршрутизация субагентов

**Параллельно** (нет зависимостей):
- Верификация разных секций документации
- Проверка статуса issues + проверка docs одновременно
- Несколько `researcher-docs` по непересекающимся секциям

**Последовательно** (результат нужен следующему шагу):
- Research -> Design -> Planning -> Implementation
- Сбор findings → сведение → валидация → применение

**Ограничения:**
- Не более 2-3 параллельных субагентов (#19100: OOM, #27794: compaction cascade)
- Всегда `maxTurns` в frontmatter (#28148: без лимита -- 153GB output)
- Не использовать `background: true` для агентов с quality gates (#25147)
- Результаты через файлы, не через возвращаемые данные (#23463: overflow context)

## Петля самоподдержки

```
research-файлы (мозг) → /scaffold (генератор) → .claude/ (выход)
        ↑                                              ↓
   /audit + /update (сенсоры) ← работает на Claude Code
```
