# AI Coding Workflow

Методология контекстной инженерии для разработки с ИИ-агентами.

## Проблема

ИИ генерирует код быстро, но без процесса вокруг него результат непредсказуем. Сложность кодовой базы растёт, скорость падает, через несколько месяцев работать становится медленнее, чем до введения ИИ.

Корень проблемы — не модель, а контекст. Агент, который получает весь проект целиком, тонет в шуме. Агент, который не получает нужной информации, галлюцинирует. Качество определяется тем, насколько точно сформирован контекст для каждой конкретной задачи.

## Решение

Четырёхфазный процесс, где каждая фаза формирует контекст для следующей:

```text
Research → Design → Planning → Implementation
```

- **Research** — параллельные субагенты исследуют кодовую базу и собирают факты в один документ. Никаких мнений, только факты.
- **Design** — агент читает результаты Research + стандарты команды и создаёт архитектурное решение. Ревью инженерами.
- **Planning** — детальный план реализации по фазам. Каждая фаза — завершённая единица работы. Ревью инженерами.
- **Implementation** — команда специализированных агентов (Lead, разработчик, тестировщик, ревьюеры) пишет код по плану с автоматическими quality gates на каждом шаге.

Два человеческих гейта до написания кода. CI как последний рубеж. Подробнее — [`methodology.md`](methodology.md).

## Что в репозитории

Методология + research-документация по Claude Code + готовый `.claude/` scaffold, поддерживающий сам себя по собственной методологии.

```text
methodology.md                          # Методология (русский)
research-claude-code-implementation.md  # Маппинг методологии на примитивы Claude Code
research-cc-primitives-reference.md     # Справочник примитивов (frontmatter, hooks, CLI, ...)
research-cc-known-issues.md             # 50 верифицированных багов с workarounds

.claude/
  agents/                              # Субагенты для самоподдержки документации
    researcher-docs.md                 #   верификация по official docs
    researcher-issues.md               #   проверка статуса GitHub issues
    reviewer-consistency.md            #   cross-reference между файлами
    reviewer-facts.md                  #   независимая проверка фактов
    doc-writer.md                      #   применение исправлений
  commands/                            # Slash-команды
    audit.md                           #   /audit — полное ревью (4 параллельных агента)
    update.md                          #   /update — обновление после нового релиза CC
    add-primitive.md                   #   /add-primitive — добавление нового примитива
    check-issues.md                    #   /check-issues — проверка статуса issues
  hooks/                               # Git hooks
  settings.json                        # Настройки проекта
```

## Research-документация

Три research-файла — это не туториал и не гайд. Это верифицированный справочник по состоянию Claude Code на февраль 2026 (v2.1.50-51), прошедший 11 раундов независимого ревью:

| Файл | Содержание |
| --- | --- |
| [`research-cc-primitives-reference.md`](research-cc-primitives-reference.md) | Все примитивы: subagents (13 frontmatter fields), hooks (17 events), skills, plugins, settings, CLI (40+ flags), agent teams |
| [`research-cc-known-issues.md`](research-cc-known-issues.md) | 50 issues (48 open) — каждый с описанием, влиянием на методологию и обходным путём. 3 security-critical |
| [`research-claude-code-implementation.md`](research-claude-code-implementation.md) | Как именно каждая фаза методологии реализуется через примитивы Claude Code |

Каждое фактическое утверждение проверено по [official docs](https://code.claude.com), статусы issues — через GitHub API.

## Самоподдержка

Проект поддерживает сам себя по собственной методологии. `/audit` запускает 4 параллельных агента:

1. **researcher-docs** (x2) — верификация каждого утверждения по official docs
2. **researcher-issues** — проверка статуса каждого issue через `gh` CLI
3. **reviewer-consistency** — cross-reference между файлами

Результаты сводятся, перепроверяются через `reviewer-facts`, и после одобрения `doc-writer` применяет исправления.

## Лицензия

MIT
