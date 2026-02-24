# Независимое критическое ревью документации

## Контекст

В этом репозитории лежат research-файлы о Claude Code CLI. Они прошли несколько раундов верификации. Твоя задача — провести **полностью независимую** проверку с нуля, как будто ты видишь эти файлы впервые.

**Scope:** только Claude Code CLI и его инструментарий (субагенты, hooks, skills, plugins, settings, CLI-флаги, TUI). Agent SDK (TS/Python) — **вне scope**.

**КРИТИЧЕСКИ ВАЖНО:**

- НЕ доверяй своим training data о Claude Code — они могут быть устаревшими
- НЕ доверяй предыдущим ревью или пометкам "верифицировано" в файлах
- НЕ доверяй MEMORY.md или другим кешированным данным в проекте
- Для КАЖДОГО проверяемого утверждения загрузи первоисточник через WebFetch или exa и сверь

## Файлы для ревью

Все `.md` файлы в корне репозитория (кроме `prompts/`):

1. `research-cc-primitives-reference.md` — справочник по примитивам Claude Code
2. `research-cc-known-issues.md` — известные баги и workarounds
3. `research-claude-code-implementation.md` — маппинг методологии на примитивы CC
4. `methodology.md` — сама методология (эталон, проверяется только полнота маппинга)

## Стратегия

### Фаза 1: Параллельные агенты (4 штуки)

Запусти 4 субагента параллельно. Каждый читает нужные файлы **самостоятельно** и верифицирует **только** через загрузку official docs. Области не пересекаются.

---

#### Агент 1: Субагенты — frontmatter, resume, memory, CLI --agents

**Файл:** `research-cc-primitives-reference.md` -> секция "Subagents"

**Метод верификации:**

1. WebFetch `https://code.claude.com/docs/en/sub-agents` — прочитать целиком
2. WebFetch `https://code.claude.com/docs/en/permissions` — режимы разрешений
3. WebFetch `https://code.claude.com/docs/en/cli-reference` — CLI --agents flag
4. exa `site:code.claude.com/docs sub-agents frontmatter` — доп. страницы

**Что проверить (каждый пункт — загрузить источник и сверить):**

- Полный список frontmatter полей: сколько их в official reference table? Совпадает ли с документом?
- Для КАЖДОГО поля: имя, тип, допустимые значения, обязательность, default
- `--agents` CLI JSON: какие поля поддерживаются? Сверить CLI reference page И sub-agents page
- Приоритет определений (CLI > project > user > plugin) — точный ли порядок?
- `color` — есть ли в official reference table или нет?
- Resume: где хранятся транскрипты? Формат пути?
- Auto-compaction: порог, env var (точное имя — это частая ошибка!)
- Memory: enum значения, пути директорий, какие tools включаются, MEMORY.md лимит
- Background: ограничения (MCP, permissions, hooks)
- Built-in субагенты: какие есть, сколько?
- Вложенные субагенты: могут ли спаунить друг друга?

---

#### Агент 2: Hooks — события, matchers, JSON, handler types

**Файл:** `research-cc-primitives-reference.md` -> секция "Hooks"

**Метод верификации:**

1. WebFetch `https://code.claude.com/docs/en/hooks` — прочитать целиком (PRIMARY source)
2. WebFetch `https://code.claude.com/docs/en/hooks-guide` — guide
3. exa `site:code.claude.com/docs hooks` — доп. страницы

**Что проверить:**

- Сколько hook-событий? Полный список с matchers для каждого
- Какие события поддерживают prompt/agent типы? Точный список
- Handler types: синтаксис каждого (command, prompt, agent) — какие поля у каждого?
- prompt/agent response schema: `ok`/`reason` формат, `$ARGUMENTS` placeholder
- Agent hook turn limit (сколько turns до возврата решения?)
- Common handler fields: timeout (ЕДИНИЦЫ! секунды или мс?), defaults для каждого типа
- Exit code семантика: 0, 2, другие — что именно происходит с stdout/stderr?
- JSON decision fields ДЛЯ КАЖДОГО события: точные поля, вложенность, допустимые значения
- Universal fields: continue, stopReason, suppressOutput, systemMessage — точное поведение
- hookSpecificOutput + hookEventName — требования
- additionalContext: для каких событий, top-level или внутри hookSpecificOutput?
- WorktreeCreate: уникальный output mechanism (stdout = путь?)
- Deprecated fields (PreToolUse)
- Common input fields (stdin JSON) — полный список для всех событий
- Per-event input fields — для КАЖДОГО из 17 событий
- Async hooks: синтаксис, ограничения
- Hooks snapshot behavior: применяются ли изменения без рестарта?
- Hooks в frontmatter субагента: поддерживается ли?
- disableAllHooks: поведение с managed settings?
- allowManagedHooksOnly: что именно блокирует?
- Env vars в hooks: какие доступны?

---

#### Агент 3: GitHub issues — статус и описание каждого

**Файл:** `research-cc-known-issues.md` — ВСЕ упомянутые issues

**Метод верификации:**

Для КАЖДОГО номера issue в файле:

1. exa `site:github.com/anthropics/claude-code/issues/{number}` — найти
2. WebFetch `https://github.com/anthropics/claude-code/issues/{number}` — прочитать

Затем поиск НОВЫХ issues:

3. exa `site:github.com/anthropics/claude-code/issues subagent hook bug 2026`
4. exa `site:github.com/anthropics/claude-code/issues worktree agent teams bug 2026`
5. exa `site:github.com/anthropics/claude-code/issues skills plugins settings bug 2026`

**Что проверить:**

- Статус КАЖДОГО issue: open или closed?
- Совпадает ли описание бага в документе с реальным issue?
- Если closed — нужен ли ещё workaround? Удалить из документа или пометить
- Есть ли новые критичные issues, которых нет в документе?
- Severity ratings — соответствуют ли реальному impact?
- Точность workarounds — работает ли предложенный обходной путь?

---

#### Агент 4: Skills, Plugins, Settings, CLI, Agent Teams

**Файл:** `research-cc-primitives-reference.md` -> секции Skills, Plugins, Settings, CLI, Agent Teams

**Метод верификации:**

1. WebFetch `https://code.claude.com/docs/en/skills`
2. WebFetch `https://code.claude.com/docs/en/plugins-reference`
3. WebFetch `https://code.claude.com/docs/en/settings`
4. WebFetch `https://code.claude.com/docs/en/cli-reference`
5. WebFetch `https://code.claude.com/docs/en/interactive-mode`
6. WebFetch `https://code.claude.com/docs/en/agent-teams`

**Что проверить:**

Skills:

- Frontmatter: полный список полей, spelling (`user-invocable`?), defaults
- Progressive disclosure: сколько уровней, как работает
- String substitutions: какие переменные доступны?
- Priority/override order
- `once` field behavior
- `allowed-tools` reliability
- Character budget: точная формула и env var

Plugins:

- Directory structure
- plugin.json schema (ВСЕ поля), какие обязательные?
- CLI commands для plugin management (install, uninstall, enable, disable, update)
- Default scope при install
- Plugin caching behavior

Settings:

- Сколько уровней иерархии? Точный порядок?
- Managed settings paths (macOS, Linux, Windows)?
- Каждое упомянутое setting — существует ли?
- `disableAllHooks`, `allowManagedHooksOnly` — поведение

CLI:

- Проверить каждую команду и флаг из документа — существует ли?
- Какие команды/флаги ПРОПУЩЕНЫ из документа?
- TUI slash-commands: полный список built-in vs что в документе

Agent Teams:

- Env var для включения
- "Delegate Mode" — есть в official docs или нет?
- Keyboard shortcuts (Shift+Down, Ctrl+T) — что делают?
- Display modes: настройки, поддерживаемые backend-ы (tmux, iTerm2?)
- Limitations — полный список из official docs vs что в документе
- Communication mechanism (Mailbox)
- Quality gate hooks (TeammateIdle, TaskCompleted)

Env vars:

- Какие официально документированы? Точные имена (частая ошибка: лишний/пропущенный `_CODE_`)

---

### Фаза 2: Сведение (основной агент)

После получения результатов всех 4 агентов:

1. **Дедупликация и конфликты** — если два агента нашли разное по одному claim, перепроверить
2. **Cross-reference** — согласованность между тремя research-файлами (числа, имена, ссылки на issues)
3. **Полнота маппинга** — все ли концепции из methodology.md покрыты в research файлах
4. **Практическая реализуемость** — можно ли запустить описанный workflow с текущими примитивами и известными багами
5. **Count verification** — совпадает ли заявленное количество issues/полей/событий с фактическим

## Правила для агентов

1. **Единственный источник правды = official docs** (code.claude.com/docs/en/*). Загружать через WebFetch
2. **GitHub issues** — через exa и WebFetch
3. **Community sources** (claudefast.com, блоги) — только для контекста, НЕ как proof
4. Для каждого утверждения: **CONFIRMED** / **CONTRADICTED** / **UNVERIFIABLE** + URL источника
5. Проверять не только "что написано", но и **"что пропущено"** — новые поля, события, фичи, баги
6. **Не доверять training data** — загружать docs через WebFetch для каждой проверки
7. **Не доверять предыдущим ревью** — проверять заново, как будто документ не верифицирован
8. **Agent SDK (TS/Python) вне scope** — пропускать всё, что касается программного SDK

## Типичные ловушки (из опыта предыдущих ревью)

- **Community != Official**: термины из блогов приписываются official docs (пример: "Delegate Mode")
- **CLI reference != Feature page**: одна страница может перечислять больше полей, чем другая (пример: --agents JSON: 8 полей в CLI ref vs 11 на sub-agents page)
- **Единицы измерения**: секунды vs миллисекунды, символы vs строки
- **Имена env vars**: лишний/пропущенный `_CODE_` в имени (пример: `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE`, НЕ `CLAUDE_CODE_AUTOCOMPACT_PCT_OVERRIDE`)
- **Deprecated fields**: могут работать, но не документированы
- **"Нельзя"**: ошибка, игнорируется, или просто не рекомендуется?
- **Числа**: "~30 plugins", "3-50 chars" — откуда цифра? Count в заголовке != реальное количество items
- **additionalContext placement**: top-level vs внутри hookSpecificOutput — зависит от события
- **Display mode naming**: setting value ("tmux") != official mode name ("Split panes")

## Формат вывода

Для каждой найденной проблемы:

```
**[CRITICAL/WARNING/INFO/UNVERIFIABLE]** Краткое описание

- **Где:** файл:строка или секция
- **Что написано:** цитата
- **Что на самом деле:** факт + URL
- **Исправление:** конкретное предложение
```

В конце:

- Таблица проблем по категориям (CRITICAL / WARNING / INFO / CONFIRMED)
- Топ-5 рисков при реальном использовании
- Конкретный список: что добавить / убрать / переписать

## Режим работы

- **По умолчанию:** только найти и описать проблемы, НЕ исправлять файлы
- **Если пользователь просит исправить:** применить все исправления, обновить MEMORY.md, закоммитить
