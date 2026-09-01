# UX Guidelines Skill Help — Usage and Triggers

Use this skill when you need consistent UX output for shell help text and
user-facing commands in the dotfiles repository.

## Usage

`/authoring:ux-guidelines [target]`

| Option | Description | Default |
|--------|-------------|---------|
| `[target]` | Function, module, or glob to bring in line with `UX_GUIDELINES.md`. | ask |
| `help` | Print this help and stop. No files are read or written. | — |

## Typical Requests

- `proxy_help() 함수를 UX 가이드라인에 맞게 리팩터링해`
- `help 텍스트를 ux_lib 함수들로 바꿔줘`
- `cc_help 스타일로 이 함수 정리해줘`
- `새 help 커맨드 만드는데 UX 가이드라인 맞춰줘` (creating a new help command)
- `shell-common 전체를 UX_GUIDELINES 기준으로 점검해서 docs/abc-review-C.md에 작성해줘`
- `docs/abc-review-CX.md로 UX 위반 사항 정리해줘`

## Modes

1. **Individual function refactoring**
   - Target: one function or module.
   - Goal: replace hardcoded formatting with semantic `ux_*` calls.
2. **Bulk compliance review**
   - Target: `shell-common/**/*.sh`.
   - Goal: produce a review document with violations, severity, and fixes.

## Inputs to Confirm

- Target file(s) or function name(s).
- Requested output path for review documents (for bulk mode).
- Whether behavior changes are allowed (default: no; presentation-only refactor).

## Deliverables

1. Updated shell code or a review Markdown document.
2. Summary with files inspected/changed.
3. Validation commands and outcomes.

For detailed workflow and rules, read:
- `references/ux-foundation.md`
- `references/refactoring-playbook.md`
- `references/bulk-review-workflow.md`
