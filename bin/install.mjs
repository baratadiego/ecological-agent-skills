#!/usr/bin/env node

// ecological-agent-skills installer
// Usage: npx ecological-agent-skills [--claude | --gemini | --cursor | --copilot | --codex | --path <dir>]

import { execFileSync } from "node:child_process";
import { existsSync, mkdirSync, cpSync } from "node:fs";
import { resolve, join } from "node:path";
import { homedir } from "node:os";

const REPO_URL = "https://github.com/baratadiego/ecological-agent-skills.git";
const PACKAGE_NAME = "ecological-agent-skills";

const TARGETS = {
  "--claude": {
    path: () => join(process.cwd(), ".claude", "skills", PACKAGE_NAME),
    label: "Claude Code",
    postInstall: `Add to your CLAUDE.md:\n  Read AGENT_CONTEXT.md from .claude/skills/${PACKAGE_NAME}/ before any ecology task.`,
  },
  "--gemini": {
    path: () => join(homedir(), ".gemini", PACKAGE_NAME, "skills"),
    label: "Gemini CLI / Antigravity",
    postInstall: "Skills will be auto-discovered by Gemini CLI.",
  },
  "--cursor": {
    path: () => join(process.cwd(), ".cursor", "skills", PACKAGE_NAME),
    label: "Cursor",
    postInstall: `Add to .cursor/rules/:\n  Read AGENT_CONTEXT.md from .cursor/skills/${PACKAGE_NAME}/ before any ecology task.`,
  },
  "--copilot": {
    path: () => join(process.cwd(), ".github", "skills", PACKAGE_NAME),
    label: "GitHub Copilot",
    postInstall: `Reference in .github/copilot-instructions.md:\n  Read AGENT_CONTEXT.md from .github/skills/${PACKAGE_NAME}/ before any ecology task.`,
  },
  "--codex": {
    path: () => join(process.cwd(), ".codex", "skills", PACKAGE_NAME),
    label: "Codex CLI",
    postInstall: "Skills installed for Codex CLI.",
  },
};

function printUsage() {
  console.log(`
ecological-agent-skills — installer for quantitative ecology AI skills

Usage:
  npx ecological-agent-skills --claude       Install for Claude Code (project-local)
  npx ecological-agent-skills --gemini       Install for Gemini CLI (~/.gemini/)
  npx ecological-agent-skills --cursor       Install for Cursor (project-local)
  npx ecological-agent-skills --copilot      Install for GitHub Copilot (project-local)
  npx ecological-agent-skills --codex        Install for Codex CLI (project-local)
  npx ecological-agent-skills --path <dir>   Install to a custom directory

Options:
  --help       Show this help message
  --version    Show version
`);
}

function getVersion() {
  return "3.1.0";
}

function main() {
  const args = process.argv.slice(2);

  if (args.includes("--help") || args.length === 0) {
    printUsage();
    process.exit(0);
  }

  if (args.includes("--version")) {
    console.log(getVersion());
    process.exit(0);
  }

  let targetPath;
  let label;
  let postInstall;

  if (args.includes("--path")) {
    const idx = args.indexOf("--path");
    const customPath = args[idx + 1];
    if (!customPath) {
      console.error("Error: --path requires a directory argument.");
      process.exit(1);
    }
    targetPath = resolve(customPath);
    label = "Custom path";
    postInstall = `Skills installed to ${targetPath}`;
  } else {
    const flag = args.find((a) => TARGETS[a]);
    if (!flag) {
      console.error(`Unknown option: ${args[0]}`);
      printUsage();
      process.exit(1);
    }
    const target = TARGETS[flag];
    targetPath = target.path();
    label = target.label;
    postInstall = target.postInstall;
  }

  console.log(`\nInstalling ecological-agent-skills for ${label}...`);
  console.log(`Target: ${targetPath}\n`);

  const tmpDir = join(
    homedir(),
    ".cache",
    "ecological-agent-skills-tmp-" + Date.now()
  );

  try {
    console.log("Cloning repository...");
    execFileSync("git", ["clone", "--depth", "1", REPO_URL, tmpDir], {
      stdio: "pipe",
    });

    mkdirSync(targetPath, { recursive: true });

    const filesToCopy = [
      "skills",
      "workflows",
      "templates",
      "examples",
      "docs",
      "AGENT_CONTEXT.md",
      "CATALOG.md",
      "environment.yaml",
      "renv.lock",
    ];

    for (const item of filesToCopy) {
      const src = join(tmpDir, item);
      const dest = join(targetPath, item);
      if (existsSync(src)) {
        cpSync(src, dest, { recursive: true });
      }
    }

    console.log("\nInstalled successfully!\n");
    console.log(`  17 skills, 13 workflows, 58 scripts\n`);
    console.log(`Next steps:`);
    console.log(`  ${postInstall}\n`);
    console.log(
      `Environment setup (optional, for running R/Python scripts):`
    );
    console.log(`  conda env create -f ${join(targetPath, "environment.yaml")}`);
    console.log(`  conda activate eco-skills\n`);
  } catch (err) {
    console.error("Installation failed:", err.message);
    process.exit(1);
  } finally {
    try {
      if (process.platform === "win32") {
        execFileSync("cmd", ["/c", "rmdir", "/s", "/q", tmpDir], {
          stdio: "pipe",
        });
      } else {
        execFileSync("rm", ["-rf", tmpDir], { stdio: "pipe" });
      }
    } catch {
      // Ignore cleanup errors
    }
  }
}

main();
