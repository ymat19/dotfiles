"""Claude Code / Codex のセッション記録を、LLM Wiki が読める Markdown のソースへ変換する。

llmwiki は .jsonl を取り込めないため形式だけを変える。何を wiki に残すかは llmwiki の guide に従う
エージェントが決めるので、ここでは選別しない。

usage: digest.py <workspace>
"""

import json
import sys
from pathlib import Path

HOME = Path.home()
CLAUDE_PROJECTS = HOME / ".claude" / "projects"
CODEX_SESSIONS = HOME / ".codex" / "sessions"


def project_name(cwd: str) -> str:
    # ワークツリーはリポジトリ本体の名前でまとめる
    return Path(cwd.split("/.claude/worktrees/")[0]).name or "unknown"


def texts(content) -> list[str]:
    if isinstance(content, str):
        return [content]
    if isinstance(content, list):
        return [b.get("text", "") for b in content if b.get("type") in ("text", "input_text", "output_text")]
    return []


def parse_claude(path: Path) -> tuple[str, list[tuple[str, str, str]]]:
    cwd, msgs = "", []
    for line in path.open(errors="replace"):
        try:
            e = json.loads(line)
        except ValueError:
            continue
        cwd = cwd or e.get("cwd", "")
        if e.get("type") not in ("user", "assistant") or e.get("isMeta") or e.get("isSidechain"):
            continue
        for t in texts(e.get("message", {}).get("content")):
            # コマンド実行の出力や caveat など、ハーネスが差し込んだ行は会話ではない
            if t.strip() and not t.lstrip().startswith("<"):
                msgs.append((e["type"], e.get("timestamp", ""), t.strip()))
    return cwd, msgs


def parse_codex(path: Path) -> tuple[str, list[tuple[str, str, str]]]:
    cwd, msgs = "", []
    for line in path.open(errors="replace"):
        try:
            e = json.loads(line)
        except ValueError:
            continue
        p = e.get("payload") or {}
        if e.get("type") == "session_meta":
            cwd = p.get("cwd", "")
        if e.get("type") != "response_item" or p.get("type") != "message" or p.get("role") not in ("user", "assistant"):
            continue
        for t in texts(p.get("content")):
            # AGENTS.md や環境情報の注入は会話ではない
            if t.strip() and not t.lstrip().startswith(("<", "# AGENTS.md")):
                msgs.append((p["role"], e.get("timestamp", ""), t.strip()))
    return cwd, msgs


def render(tool: str, path: Path, cwd: str, msgs: list[tuple[str, str, str]]) -> str:
    head = [
        f"# {tool} session {path.stem}",
        "",
        f"- project: {project_name(cwd)}",
        f"- cwd: {cwd}",
        f"- period: {msgs[0][1]} 〜 {msgs[-1][1]}",
        "",
    ]
    return "\n".join(head) + "\n" + "\n".join(f"## {role}\n\n{text}\n" for role, _, text in msgs)


def main(workspace: Path) -> None:
    # ジョブ自身が workspace で起動した claude のセッションまで変換すると、自分の作業記録を毎晩取り込み続ける
    own = str(workspace).replace("/", "-").replace(".", "-")
    found = [("claude", p) for p in CLAUDE_PROJECTS.glob("*/*.jsonl") if p.parent.name != own]
    found += [("codex", p) for p in CODEX_SESSIONS.glob("**/*.jsonl")]

    out_dir = workspace / "sources" / "sessions"
    out_dir.mkdir(parents=True, exist_ok=True)
    for tool, p in found:
        cwd, msgs = (parse_claude if tool == "claude" else parse_codex)(p)
        if not msgs:
            continue
        dest = out_dir / f"{msgs[0][1][:10]}-{tool}-{project_name(cwd)}-{p.stem[-8:]}.md"
        text = render(tool, p, cwd, msgs)
        # 内容が変わらないのに書き直すと、llmwiki の監視が毎晩全件を再インデックスする
        if not dest.exists() or dest.read_text() != text:
            dest.write_text(text)


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    main(Path(sys.argv[1]))
