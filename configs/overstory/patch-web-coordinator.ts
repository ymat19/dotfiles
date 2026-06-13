// overstory の Web UI から tmux (サブスク枠) coordinator へ send/ask できるようにする patch。
//
// 既定の overstory は serve/coordinator-actions.ts で、coordinator が tmux 起動
// (tmuxSession !== "") の場合に "Coordinator is tmux-only — use 'ov coordinator send'
// from the shell" と ConflictError を投げ、Web UI からの操作を拒否する
// (Web 操作には headless = Agent 枠が必要、という設計)。
//
// しかし CLI の `ov coordinator send/ask` は mail 書込み + tmux send-keys nudge
// (nudgeAgent) で tmux coordinator に配送できている。そこで Web ハンドラの throw を
// 同じ nudge フォールバックに差し替え、サブスク枠の tmux coordinator を Web UI から
// 操作可能にする。
//
// 適用先: src/commands/serve/coordinator-actions.ts
// whitespace 非依存の正規表現 + 件数アサートで、上流の整形差にある程度耐える。
import { readFileSync, writeFileSync } from "node:fs";

const file = process.argv[2];
let src = readFileSync(file, "utf8");

function replaceOnce(label: string, find: string | RegExp, repl: string) {
	if (typeof find === "string") {
		const idx = src.indexOf(find);
		if (idx === -1) throw new Error(`[patch] target not found: ${label}`);
		if (src.indexOf(find, idx + find.length) !== -1)
			throw new Error(`[patch] target not unique: ${label}`);
		src = src.replace(find, repl);
	} else {
		const m = src.match(find);
		if (!m) throw new Error(`[patch] regex not found: ${label}`);
		src = src.replace(find, repl);
	}
	console.log(`[patch] ok: ${label}`);
}

// 1) import nudgeAgent
replaceOnce(
	"import-nudge",
	'} from "../coordinator.ts";',
	'} from "../coordinator.ts";\nimport { nudgeAgent } from "../nudge.ts";',
);

// 2) send: tmux-only throw -> fallback flag
replaceOnce(
	"send-throw",
	/if \(conn === undefined && session\.tmuxSession !== ""\) \{[\s\S]*?'ov coordinator send'[\s\S]*?\n\t*\}/,
	'const __tmuxFallback = conn === undefined && session.tmuxSession !== "";',
);

// 3) ask: tmux-only throw -> fallback flag
replaceOnce(
	"ask-throw",
	/if \(conn === undefined && session\.tmuxSession !== ""\) \{[\s\S]*?'ov coordinator ask'[\s\S]*?\n\t*\}/,
	'const __tmuxFallback = conn === undefined && session.tmuxSession !== "";',
);

// 4) send: nudge the tmux coordinator before returning
replaceOnce(
	"send-nudge",
	'\t\treturn { messageId };',
	'\t\tif (__tmuxFallback) {\n\t\t\ttry {\n\t\t\t\tawait nudgeAgent(deps.projectRoot, COORDINATOR_NAME, `[DISPATCH] ${opts.subject}: ${body.slice(0, 500)}`, true);\n\t\t\t} catch {}\n\t\t}\n\t\treturn { messageId };',
);

// 5) ask: nudge the tmux coordinator before polling for a reply
replaceOnce(
	"ask-nudge",
	'\t\tconst pollIntervalMs = deps._askPollIntervalMs ?? DEFAULT_ASK_POLL_INTERVAL_MS;',
	'\t\tif (__tmuxFallback) {\n\t\t\ttry {\n\t\t\t\tawait nudgeAgent(deps.projectRoot, COORDINATOR_NAME, `[ASK] ${opts.subject}: ${body.slice(0, 500)}`, true);\n\t\t\t} catch {}\n\t\t}\n\t\tconst pollIntervalMs = deps._askPollIntervalMs ?? DEFAULT_ASK_POLL_INTERVAL_MS;',
);

writeFileSync(file, src);
console.log("[patch] done");
