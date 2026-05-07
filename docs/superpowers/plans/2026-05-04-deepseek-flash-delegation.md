# DeepSeek Flash Delegation — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Set up three `~/bin/` CLI tools that delegate I/O-heavy tasks to `deepseek-v4-flash`, reducing Anthropic token consumption in Claude Code.

**Architecture:** Three Python source modules in `~/.deepseek-tools/`, each called by a thin bash wrapper script in `~/bin/`. All use the `anthropic` SDK pointed at `https://api.deepseek.com/anthropic` with `DEEPSEEK_API_KEY`. A global `~/.claude/CLAUDE.md` and project `CLAUDE.md` route Claude to shell out to these tools.

**Tech Stack:** Python 3, `anthropic` SDK, `pytest`, Git Bash (Windows — `~` = `C:\Users\RodDriscoll`)

---

## File Map

| Action | Path | Responsibility |
|--------|------|----------------|
| Create | `~/.deepseek-tools/ask_deepseek.py` | Read files + question → LLM → stdout |
| Create | `~/.deepseek-tools/deepseek_write.py` | Prompt + context files → streaming LLM → stdout |
| Create | `~/.deepseek-tools/extract_chat.py` | Parse JSONL/JSON transcript → clean markdown |
| Create | `~/.deepseek-tools/tests/test_ask_deepseek.py` | Tests for ask_deepseek |
| Create | `~/.deepseek-tools/tests/test_deepseek_write.py` | Tests for deepseek_write |
| Create | `~/.deepseek-tools/tests/test_extract_chat.py` | Tests for extract_chat |
| Create | `~/bin/ask-deepseek` | Bash wrapper calling venv Python |
| Create | `~/bin/deepseek-write` | Bash wrapper calling venv Python |
| Create | `~/bin/extract-chat` | Bash wrapper calling venv Python |
| Modify | `~/.bashrc` | Add `~/bin` to PATH, set `DEEPSEEK_API_KEY` |
| Create | `~/.claude/CLAUDE.md` | Global routing rules |
| Create | `CLAUDE.md` | Project routing rules |

---

## Task 1: Bootstrap environment

**Files:** Modify `~/.bashrc`, create directories and venv.

- [ ] **Step 1: Create directories**

```bash
mkdir -p ~/bin ~/.deepseek-tools/tests
```

- [ ] **Step 2: Add ~/bin to PATH and placeholder API key in ~/.bashrc**

Open `~/.bashrc` (create it if it doesn't exist: `touch ~/.bashrc`) and append:

```bash
export PATH="$HOME/bin:$PATH"
export DEEPSEEK_API_KEY="your-deepseek-api-key-here"
```

Replace `your-deepseek-api-key-here` with your real key from https://platform.deepseek.com/api_keys

- [ ] **Step 3: Reload shell config**

```bash
source ~/.bashrc
```

Expected: no errors. Verify with `echo $DEEPSEEK_API_KEY` — should print your key.

- [ ] **Step 4: Create the venv and install dependencies**

```bash
python3 -m venv ~/.deepseek-venv
~/.deepseek-venv/Scripts/pip install anthropic pytest
```

Expected output ends with: `Successfully installed anthropic-... pytest-...`

- [ ] **Step 5: Verify install**

```bash
~/.deepseek-venv/Scripts/python -c "import anthropic; print(anthropic.__version__)"
```

Expected: prints a version string like `0.40.0` (or higher).

---

## Task 2: `ask_deepseek.py` — read files and answer a question

**Files:**
- Create: `~/.deepseek-tools/ask_deepseek.py`
- Create: `~/.deepseek-tools/tests/test_ask_deepseek.py`

- [ ] **Step 1: Write the failing tests**

Create `~/.deepseek-tools/tests/test_ask_deepseek.py`:

```python
import pytest
import os
import sys

sys.path.insert(0, os.path.expanduser("~/.deepseek-tools"))
import ask_deepseek


def test_ask_includes_file_content_in_prompt(monkeypatch, tmp_path):
    f = tmp_path / "code.lua"
    f.write_text("function add(a, b) return a + b end")

    captured_prompt = {}

    class FakeContent:
        text = "it adds two numbers"

    class FakeMessage:
        content = [FakeContent()]

    class FakeMessages:
        def create(self, **kwargs):
            captured_prompt["content"] = kwargs["messages"][0]["content"]
            assert kwargs["model"] == "deepseek-v4-flash"
            assert kwargs["max_tokens"] == 4096
            return FakeMessage()

    class FakeClient:
        messages = FakeMessages()

    monkeypatch.setenv("DEEPSEEK_API_KEY", "test-key")
    monkeypatch.setattr(ask_deepseek, "make_client", lambda: FakeClient())

    result = ask_deepseek.run("what does this do?", [str(f)])
    assert result == "it adds two numbers"
    assert "function add" in captured_prompt["content"]
    assert "what does this do?" in captured_prompt["content"]


def test_ask_missing_file_warns_and_continues(monkeypatch, capsys):
    class FakeContent:
        text = "ok"

    class FakeMessage:
        content = [FakeContent()]

    class FakeMessages:
        def create(self, **kwargs):
            return FakeMessage()

    class FakeClient:
        messages = FakeMessages()

    monkeypatch.setenv("DEEPSEEK_API_KEY", "test-key")
    monkeypatch.setattr(ask_deepseek, "make_client", lambda: FakeClient())

    result = ask_deepseek.run("question", ["/nonexistent/file.txt"])
    err = capsys.readouterr().err
    assert "warning" in err.lower()
    assert result == "ok"
```

- [ ] **Step 2: Run the tests — verify they fail**

```bash
~/.deepseek-venv/Scripts/python -m pytest ~/.deepseek-tools/tests/test_ask_deepseek.py -v
```

Expected: `ImportError` — `ask_deepseek` module not found.

- [ ] **Step 3: Write `ask_deepseek.py`**

Create `~/.deepseek-tools/ask_deepseek.py`:

```python
import sys
import os
import anthropic


def make_client():
    return anthropic.Anthropic(
        api_key=os.environ["DEEPSEEK_API_KEY"],
        base_url="https://api.deepseek.com/anthropic",
    )


def run(question, file_paths):
    parts = [question]
    for path in file_paths:
        try:
            with open(path) as f:
                parts.append(f"\n--- {path} ---\n{f.read()}")
        except FileNotFoundError:
            print(f"warning: {path} not found", file=sys.stderr)

    client = make_client()
    msg = client.messages.create(
        model="deepseek-v4-flash",
        max_tokens=4096,
        messages=[{"role": "user", "content": "\n".join(parts)}],
    )
    return msg.content[0].text


def main():
    if len(sys.argv) < 2:
        print("usage: ask-deepseek <question> [file ...]", file=sys.stderr)
        sys.exit(1)
    print(run(sys.argv[1], sys.argv[2:]))


if __name__ == "__main__":
    main()
```

- [ ] **Step 4: Run the tests — verify they pass**

```bash
~/.deepseek-venv/Scripts/python -m pytest ~/.deepseek-tools/tests/test_ask_deepseek.py -v
```

Expected: `2 passed`

- [ ] **Step 5: Commit**

```bash
cd ~/.deepseek-tools
git init   # only if not already a git repo
git add ask_deepseek.py tests/test_ask_deepseek.py
git commit -m "feat: add ask_deepseek with tests"
```

---

## Task 3: `deepseek_write.py` — stream boilerplate generation

**Files:**
- Create: `~/.deepseek-tools/deepseek_write.py`
- Create: `~/.deepseek-tools/tests/test_deepseek_write.py`

- [ ] **Step 1: Write the failing tests**

Create `~/.deepseek-tools/tests/test_deepseek_write.py`:

```python
import pytest
import os
import sys

sys.path.insert(0, os.path.expanduser("~/.deepseek-tools"))
import deepseek_write


def test_write_streams_output_to_stdout(monkeypatch, tmp_path, capsys):
    ctx = tmp_path / "ctx.lua"
    ctx.write_text("-- context")

    class FakeStream:
        text_stream = iter(["def ", "foo(): ", "pass"])
        def __enter__(self): return self
        def __exit__(self, *a): pass

    class FakeMessages:
        def stream(self, **kwargs):
            assert kwargs["model"] == "deepseek-v4-flash"
            assert kwargs["max_tokens"] == 8192
            assert "write a stub" in kwargs["messages"][0]["content"]
            assert "context" in kwargs["messages"][0]["content"]
            return FakeStream()

    class FakeClient:
        messages = FakeMessages()

    monkeypatch.setenv("DEEPSEEK_API_KEY", "test-key")
    monkeypatch.setattr(deepseek_write, "make_client", lambda: FakeClient())

    deepseek_write.run("write a stub", [str(ctx)])
    out = capsys.readouterr().out
    assert "def foo(): pass" in out.replace("\n", "")


def test_write_missing_file_warns(monkeypatch, capsys):
    class FakeStream:
        text_stream = iter(["ok"])
        def __enter__(self): return self
        def __exit__(self, *a): pass

    class FakeMessages:
        def stream(self, **kwargs): return FakeStream()

    class FakeClient:
        messages = FakeMessages()

    monkeypatch.setenv("DEEPSEEK_API_KEY", "test-key")
    monkeypatch.setattr(deepseek_write, "make_client", lambda: FakeClient())

    deepseek_write.run("prompt", ["/no/such/file"])
    err = capsys.readouterr().err
    assert "warning" in err.lower()
```

- [ ] **Step 2: Run the tests — verify they fail**

```bash
~/.deepseek-venv/Scripts/python -m pytest ~/.deepseek-tools/tests/test_deepseek_write.py -v
```

Expected: `ImportError` — `deepseek_write` not found.

- [ ] **Step 3: Write `deepseek_write.py`**

Create `~/.deepseek-tools/deepseek_write.py`:

```python
import sys
import os
import anthropic


def make_client():
    return anthropic.Anthropic(
        api_key=os.environ["DEEPSEEK_API_KEY"],
        base_url="https://api.deepseek.com/anthropic",
    )


def run(prompt, file_paths):
    parts = [prompt]
    for path in file_paths:
        try:
            with open(path) as f:
                parts.append(f"\n--- {path} ---\n{f.read()}")
        except FileNotFoundError:
            print(f"warning: {path} not found", file=sys.stderr)

    client = make_client()
    with client.messages.stream(
        model="deepseek-v4-flash",
        max_tokens=8192,
        messages=[{"role": "user", "content": "\n".join(parts)}],
    ) as stream:
        for text in stream.text_stream:
            print(text, end="", flush=True)
    print()


def main():
    if len(sys.argv) < 2:
        print("usage: deepseek-write <prompt> [context_file ...]", file=sys.stderr)
        sys.exit(1)
    run(sys.argv[1], sys.argv[2:])


if __name__ == "__main__":
    main()
```

- [ ] **Step 4: Run the tests — verify they pass**

```bash
~/.deepseek-venv/Scripts/python -m pytest ~/.deepseek-tools/tests/test_deepseek_write.py -v
```

Expected: `2 passed`

- [ ] **Step 5: Commit**

```bash
cd ~/.deepseek-tools
git add deepseek_write.py tests/test_deepseek_write.py
git commit -m "feat: add deepseek_write with streaming and tests"
```

---

## Task 4: `extract_chat.py` — strip transcripts to clean markdown

**Files:**
- Create: `~/.deepseek-tools/extract_chat.py`
- Create: `~/.deepseek-tools/tests/test_extract_chat.py`

- [ ] **Step 1: Write the failing tests**

Create `~/.deepseek-tools/tests/test_extract_chat.py`:

```python
import json
import os
import sys

sys.path.insert(0, os.path.expanduser("~/.deepseek-tools"))
from extract_chat import extract


def test_extract_json_array_with_text_blocks(tmp_path):
    transcript = [
        {"role": "user", "content": "explain this code"},
        {"role": "assistant", "content": [
            {"type": "text", "text": "it does X"},
            {"type": "tool_use", "id": "1", "name": "Read", "input": {}},
        ]},
    ]
    f = tmp_path / "t.json"
    f.write_text(json.dumps(transcript))

    result = extract(str(f))
    assert "**Human**" in result
    assert "explain this code" in result
    assert "**Assistant**" in result
    assert "it does X" in result
    assert "tool_use" not in result
    assert "Read" not in result


def test_extract_jsonl_format(tmp_path):
    lines = [
        json.dumps({"role": "user", "content": "first question"}),
        json.dumps({"role": "assistant", "content": "first answer"}),
        json.dumps({"role": "system", "content": "system — must be excluded"}),
    ]
    f = tmp_path / "t.jsonl"
    f.write_text("\n".join(lines))

    result = extract(str(f))
    assert "first question" in result
    assert "first answer" in result
    assert "system" not in result


def test_extract_skips_empty_content(tmp_path):
    transcript = [
        {"role": "user", "content": ""},
        {"role": "assistant", "content": "real response"},
    ]
    f = tmp_path / "t.json"
    f.write_text(json.dumps(transcript))

    result = extract(str(f))
    assert result.count("**Human**") == 0
    assert result.count("**Assistant**") == 1


def test_extract_human_role_alias(tmp_path):
    transcript = [{"role": "human", "content": "hello"}]
    f = tmp_path / "t.json"
    f.write_text(json.dumps(transcript))

    result = extract(str(f))
    assert "**Human**" in result
    assert "hello" in result
```

- [ ] **Step 2: Run the tests — verify they fail**

```bash
~/.deepseek-venv/Scripts/python -m pytest ~/.deepseek-tools/tests/test_extract_chat.py -v
```

Expected: `ImportError` — `extract_chat` module not found.

- [ ] **Step 3: Write `extract_chat.py`**

Create `~/.deepseek-tools/extract_chat.py`:

```python
import sys
import json


def extract(path):
    with open(path) as f:
        content = f.read().strip()

    if content.startswith("["):
        entries = json.loads(content)
    else:
        entries = [json.loads(line) for line in content.splitlines() if line.strip()]

    output = []
    for entry in entries:
        role = entry.get("role") or entry.get("type", "")
        if role not in ("user", "human", "assistant"):
            continue

        raw = entry.get("content", "")
        if isinstance(raw, list):
            texts = [b["text"] for b in raw if isinstance(b, dict) and b.get("type") == "text"]
            text = "\n".join(texts)
        else:
            text = str(raw)

        if text.strip():
            label = "**Human**" if role in ("user", "human") else "**Assistant**"
            output.append(f"{label}:\n{text.strip()}\n")

    return "\n".join(output)


def main():
    if len(sys.argv) != 2:
        print("usage: extract-chat <transcript.json|jsonl>", file=sys.stderr)
        sys.exit(1)
    print(extract(sys.argv[1]))


if __name__ == "__main__":
    main()
```

- [ ] **Step 4: Run all tests — verify they pass**

```bash
~/.deepseek-venv/Scripts/python -m pytest ~/.deepseek-tools/tests/ -v
```

Expected: `8 passed` (2 from test_ask_deepseek + 2 from test_deepseek_write + 4 from test_extract_chat)

- [ ] **Step 5: Commit**

```bash
cd ~/.deepseek-tools
git add extract_chat.py tests/test_extract_chat.py
git commit -m "feat: add extract_chat with tests"
```

---

## Task 5: Bash wrapper scripts in `~/bin/`

**Files:** Create `~/bin/ask-deepseek`, `~/bin/deepseek-write`, `~/bin/extract-chat`

Each wrapper resolves the venv Python path (Windows `Scripts/python` or Unix `bin/python3`) and delegates to the matching module.

- [ ] **Step 1: Write `~/bin/ask-deepseek`**

```bash
#!/usr/bin/env bash
PYTHON="$HOME/.deepseek-venv/Scripts/python"
[ ! -f "$PYTHON" ] && PYTHON="$HOME/.deepseek-venv/bin/python3"
exec "$PYTHON" "$HOME/.deepseek-tools/ask_deepseek.py" "$@"
```

- [ ] **Step 2: Write `~/bin/deepseek-write`**

```bash
#!/usr/bin/env bash
PYTHON="$HOME/.deepseek-venv/Scripts/python"
[ ! -f "$PYTHON" ] && PYTHON="$HOME/.deepseek-venv/bin/python3"
exec "$PYTHON" "$HOME/.deepseek-tools/deepseek_write.py" "$@"
```

- [ ] **Step 3: Write `~/bin/extract-chat`**

```bash
#!/usr/bin/env bash
PYTHON="$HOME/.deepseek-venv/Scripts/python"
[ ! -f "$PYTHON" ] && PYTHON="$HOME/.deepseek-venv/bin/python3"
exec "$PYTHON" "$HOME/.deepseek-tools/extract_chat.py" "$@"
```

- [ ] **Step 4: Make all three executable**

```bash
chmod +x ~/bin/ask-deepseek ~/bin/deepseek-write ~/bin/extract-chat
```

- [ ] **Step 5: Reload PATH and verify commands are discoverable**

```bash
source ~/.bashrc
which ask-deepseek
```

Expected: `/c/Users/RodDriscoll/bin/ask-deepseek`

- [ ] **Step 6: Smoke test — run without args, expect usage message**

```bash
ask-deepseek
```

Expected (stderr): `usage: ask-deepseek <question> [file ...]`

```bash
deepseek-write
```

Expected (stderr): `usage: deepseek-write <prompt> [context_file ...]`

```bash
extract-chat
```

Expected (stderr): `usage: extract-chat <transcript.json|jsonl>`

- [ ] **Step 7: Commit**

```bash
cd ~/.deepseek-tools
git add ../bin/ask-deepseek ../bin/deepseek-write ../bin/extract-chat
git commit -m "feat: add bash wrapper scripts"
```

> If `~/bin` is outside the `~/.deepseek-tools` git repo, commit the wrappers with:
> ```bash
> cd ~/bin
> git init
> git add ask-deepseek deepseek-write extract-chat
> git commit -m "feat: add deepseek bash wrappers"
> ```

---

## Task 6: Global CLAUDE.md routing rules

**Files:** Create `~/.claude/CLAUDE.md`

- [ ] **Step 1: Check if `~/.claude/CLAUDE.md` already exists**

```bash
cat ~/.claude/CLAUDE.md 2>/dev/null || echo "(does not exist)"
```

- [ ] **Step 2: Create `~/.claude/CLAUDE.md`** (or append if it already has content)

If the file does not exist, create it:

```bash
cat > ~/.claude/CLAUDE.md << 'EOF'
# Global Claude Code Rules

## Token Delegation Rules

To preserve Anthropic token quota, delegate I/O-heavy work to DeepSeek Flash via these shell tools:

- **Reading files totalling more than ~200 lines** → use the Bash tool to run `ask-deepseek "<question>" <file1> [file2 ...]`
- **Generating boilerplate** (tests, configs, stubs, repetitive code) → use the Bash tool to run `deepseek-write "<prompt>" [context_file ...]`
- **Summarising a Claude session transcript** → use the Bash tool to run `extract-chat <transcript.json>`

Reserve your own reasoning for: architecture decisions, debugging logic, reviewing DeepSeek output, and writing non-boilerplate code.

### Examples

```bash
# Summarise a large file without burning tokens
ask-deepseek "what public functions does this expose?" src/plugin.lua

# Generate test stubs from a source file
deepseek-write "write unit test stubs for every function in this file" controls.lua > tests_stub.lua

# Clean up a session transcript for documentation
extract-chat ~/.claude/projects/myproject/session.jsonl > summary.md
```
EOF
```

If the file already has content, append only the `## Token Delegation Rules` section.

- [ ] **Step 3: Verify the file looks correct**

```bash
cat ~/.claude/CLAUDE.md
```

Expected: the content above is visible.

---

## Task 7: Project CLAUDE.md

**Files:** Create `CLAUDE.md` in the project root (`q-sys-plugin-novastar/`)

- [ ] **Step 1: Write project `CLAUDE.md`**

```markdown
# Q-SYS NovaStar Plugin — Claude Code Rules

## Project Context

This is a Q-SYS plugin for NovaStar LED processors (VX600, VX1000, TU series). Source is Lua.
Primary files: `plugin.lua`, `controls.lua`, `layout.lua`, `runtime.lua`.

## Token Delegation (Project-Specific)

In addition to the global delegation rules, apply these specifically:

- When reading protocol docs (PDF or txt in `docs/`) to answer a question → use `ask-deepseek`
- When generating repetitive Lua command tables or control definitions → use `deepseek-write`
- Do NOT use `ask-deepseek` for debugging runtime behaviour — that requires your own reasoning.
```

- [ ] **Step 2: Commit the project CLAUDE.md**

```bash
git add CLAUDE.md
git commit -m "docs: add CLAUDE.md with token delegation routing rules"
```

---

## Task 8: End-to-end live smoke test

Requires a real `DEEPSEEK_API_KEY` set in `~/.bashrc`.

- [ ] **Step 1: Test `ask-deepseek` against a real project file**

```bash
ask-deepseek "in one sentence, what does this file do?" runtime.lua
```

Expected: a one-sentence description printed to stdout. No errors.

- [ ] **Step 2: Test `deepseek-write` with a small prompt**

```bash
deepseek-write "write a Lua function that clamps a number between min and max"
```

Expected: streamed Lua function printed to stdout.

- [ ] **Step 3: Test `extract-chat` against a real session file**

```bash
ls ~/.claude/projects/
```

Pick one JSONL session file from the output, then:

```bash
extract-chat ~/.claude/projects/<project-dir>/<session>.jsonl | head -40
```

Expected: clean `**Human**` / `**Assistant**` dialogue, no tool calls or metadata.

- [ ] **Step 4: All three pass — implementation complete**
