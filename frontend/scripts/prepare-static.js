const fs = require("fs");
const path = require("path");

const frontendRoot = path.resolve(__dirname, "..");
const outputDirectory = path.join(frontendRoot, "dist");

fs.mkdirSync(outputDirectory, { recursive: true });

for (const fileName of ["index.html", "style.css", "favicon.ico"]) {
  fs.copyFileSync(
    path.join(frontendRoot, fileName),
    path.join(outputDirectory, fileName)
  );
}
