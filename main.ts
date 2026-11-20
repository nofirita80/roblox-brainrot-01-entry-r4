// Steal a Snackrot — entrypoint for make.fun's roblox-brainrot-01.
// The game itself is the Rojo project beside this file, built into
// game.rbxl with `rojo build default.project.json --output game.rbxl`.
// This script hands the entry in: it copies game.rbxl, src/,
// screenshots/ and PLAY.json to the output directory and writes
// dossier.json, the summary the judge reads, using the kit's own
// vendored library (vendor/makefun-roblox.ts, unchanged).
//
// The grader runs it as:
//   mkdir -p out && MAKEFUN_OUTPUT_DIR=out node main.ts
// and outside the grader, MAKEFUN_OUTPUT_DIR stands in for /output.

import { copyFileSync, cpSync, existsSync, mkdirSync, writeFileSync } from "node:fs";
import { basename, join } from "node:path";
import { fileURLToPath } from "node:url";
import { buildDossier } from "./vendor/makefun-roblox.ts";

const here = fileURLToPath(new URL(".", import.meta.url));
const out = process.env.MAKEFUN_OUTPUT_DIR ?? "/output";

// Leave out every file or directory whose name starts with a dot:
// a .gitkeep or .DS_Store copied into the output fails the entry.
function notDotted(path: string): boolean {
	return !basename(path).startsWith(".");
}

function copyTree(from: string, to: string): void {
	if (!existsSync(from)) {
		return;
	}
	mkdirSync(to, { recursive: true });
	cpSync(from, to, { recursive: true, filter: notDotted });
}

mkdirSync(out, { recursive: true });
copyFileSync(join(here, "game.rbxl"), join(out, "game.rbxl"));
copyFileSync(join(here, "PLAY.json"), join(out, "PLAY.json"));
copyTree(join(here, "src"), join(out, "src"));
copyTree(join(here, "screenshots"), join(out, "screenshots"));

// The scorer's caps, as the kit's reference names them: only
// text_max_bytes shapes the byte counts; the rest refuse an entry
// the scorer would refuse (more than 4 screenshots, one over
// 256 KiB, a place of more than 500000 instances, scripts whose
// sources come to over 8 MiB or whose paths come to over 1048576
// characters in all).
writeFileSync(
	join(out, "dossier.json"),
	buildDossier(out, {
		text_max_bytes: 65536,
		screenshots: { max: 4, max_bytes: 262144 },
		max_instances: 500000,
		scripts_max_source_bytes: 8388608,
		scripts_max_path_chars: 1048576,
	}),
);
