const fs = require("fs");
const path = require("path");
const { spawnSync } = require("child_process");

const root = path.resolve(__dirname, "..");
const src = path.join(root, "src");
const purty = path.join(
  root,
  "node_modules",
  ".bin",
  process.platform === "win32" ? "purty.cmd" : "purty"
);

function listPursFiles(dir) {
  return fs.readdirSync(dir, { withFileTypes: true }).flatMap((entry) => {
    const fullPath = path.join(dir, entry.name);

    if (entry.isDirectory()) {
      return listPursFiles(fullPath);
    }

    return entry.isFile() && entry.name.endsWith(".purs") ? [fullPath] : [];
  });
}

for (const file of listPursFiles(src)) {
  const result = spawnSync(purty, [file], {
    cwd: root,
    encoding: "utf8",
    shell: process.platform === "win32",
  });

  if (result.error) {
    console.error(result.error.message);
    process.exit(1);
  }

  if (result.status !== 0) {
    process.stderr.write(result.stderr || "");
    process.exit(result.status || 1);
  }

  fs.writeFileSync(file, result.stdout);
  console.log(`Formatted ${path.relative(root, file)}`);
}
