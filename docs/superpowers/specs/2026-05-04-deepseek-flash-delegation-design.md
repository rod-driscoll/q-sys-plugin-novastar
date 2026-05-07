# DeepSeek Flash Delegation — Design Spec
**Date:** 2026-05-04  
**Status:** Approved

## Problem

Claude Code's weekly Anthropic token limit is exhausted within days, primarily by I/O-heavy tasks: reading large files, generating boilerplate, and summarising transcripts. These tasks don't require Claude's reasoning — they just burn quota.

## Solution

Delegate I/O-heavy work to `deepseek-v4-flash` via three small CLI scripts. Claude Code (Anthropic) is reserved for complex reasoning. Routing rules in CLAUDE.md tell Claude when to delegate.

## Architecture

```
Claude Code (Anthropic, main reasoning)
    │
    ├─ complex thinking       → stays with Claude
    ├─ read large files       → ask-deepseek
    ├─ generate boilerplate   → deepseek-write
    └─ strip chat transcripts → extract-chat
                                    │
                                    └─→ deepseek-v4-flash
                                        https://api.deepseek.com/anthropic
```

## Components

### Scripts — `~/bin/`

Three Python scripts, no `.py` extension, `chmod +x`. All use a shared venv at `~/.deepseek-venv/`.

#### `ask-deepseek`
- **Purpose:** Read one or more files and answer a question about them
- **Usage:** `ask-deepseek "what does this do?" file1.lua file2.lua`
- **Behaviour:** Reads file contents, sends question + contents to `deepseek-v4-flash`, prints answer to stdout
- **Replaces:** Claude reading large files directly (~8,000 tokens → ~400 tokens per task)

#### `deepseek-write`
- **Purpose:** Generate boilerplate (tests, configs, stubs) from a prompt with optional context files
- **Usage:** `deepseek-write "write unit tests for this function" controls.lua > tests.lua`
- **Behaviour:** Streams generated output to stdout; Claude reviews/edits the result minimally
- **Replaces:** Claude generating boilerplate from scratch (~5,000 tokens → ~200 tokens per task)

#### `extract-chat`
- **Purpose:** Strip a Claude session transcript to clean human↔assistant dialogue
- **Usage:** `extract-chat session.json > summary.md`
- **Behaviour:** Reads JSON transcript, removes tool calls / system prompts / metadata, outputs plain markdown
- **Replaces:** Claude summarising its own transcripts for documentation

### API Configuration

| Setting | Value |
|---|---|
| SDK | `anthropic` Python package |
| `base_url` | `https://api.deepseek.com/anthropic` |
| `api_key` | `os.environ["DEEPSEEK_API_KEY"]` |
| Model | `deepseek-v4-flash` |
| Max tokens | 4096 (scripts), 8192 (deepseek-write) |

`DEEPSEEK_API_KEY` is a dedicated env var — separate from `ANTHROPIC_AUTH_TOKEN` — so scripts do not interfere with the main Claude Code session.

### CLAUDE.md Routing Rules

Added to **global** `~/.claude/CLAUDE.md` (applies to all projects):

```markdown
## Token Delegation Rules

Use these tools instead of working directly when:
- Reading files totalling more than ~200 lines → shell out to `ask-deepseek`
- Generating boilerplate (tests, configs, stubs) → shell out to `deepseek-write`
- Summarising or documenting a chat transcript → shell out to `extract-chat`

Reserve your own reasoning for: architecture decisions, debugging logic,
reviewing deepseek output, and writing non-boilerplate code.
```

A project-level `CLAUDE.md` in this repo may add project-specific routing rules on top.

## Setup Steps

1. Create `~/bin/` directory (`C:\Users\RodDriscoll\bin` in Windows terms)
2. Add `~/bin/` to `PATH` in `~/.bashrc` (Git Bash — Claude Code's Bash tool uses Git Bash on Windows)
3. Create venv: `python3 -m venv ~/.deepseek-venv && ~/.deepseek-venv/bin/pip install anthropic`
4. Write the three scripts to `~/bin/`
5. Make scripts executable: `chmod +x ~/bin/ask-deepseek ~/bin/deepseek-write ~/bin/extract-chat`
6. Add `export DEEPSEEK_API_KEY=<key>` to `~/.bashrc`
7. Create/update `~/.claude/CLAUDE.md` with routing rules
8. Create project-level `CLAUDE.md` in this repo

## Out of Scope

- Replacing Claude Code's main model with DeepSeek (Option A)
- Automatic token counting / routing decisions
- Windows `.bat` wrappers (scripts run via Git Bash / WSL which Claude Code's Bash tool uses)

## Success Criteria

- `ask-deepseek`, `deepseek-write`, `extract-chat` callable from any terminal
- Each script returns a correct response using `deepseek-v4-flash`
- Global CLAUDE.md routing rules in place
- Claude Code delegates file-reading and boilerplate tasks without manual prompting
