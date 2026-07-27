import { describe, expect, it } from "bun:test";
import {
  chmod,
  mkdir,
  mkdtemp,
  readFile,
  rm,
  symlink,
  writeFile,
} from "node:fs/promises";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";

const fixedVersion = "0.0.28-k-kit.1";
const releaseUrl = `https://github.com/K-Kit/t3code/releases/tag/v${fixedVersion}`;
const nodeExecutable = Bun.which("node");
const npmExecutable = Bun.which("npm");

if (nodeExecutable === null) {
  throw new Error("node is required to test the rendered T3 Code installer");
}

const nodeVersion = Bun.spawnSync([nodeExecutable, "--version"])
  .stdout.toString()
  .trim()
  .slice(1);

const variants = [
  {
    name: "coder",
    moduleRoot: ".coder-modules/coder/t3code",
    template: resolve(import.meta.dir, "scripts/install.sh.tftpl"),
  },
  {
    name: "k-kit",
    moduleRoot: ".coder-modules/k-kit/t3code",
    template: resolve(
      import.meta.dir,
      "../../../k-kit/modules/t3code/scripts/install.sh.tftpl",
    ),
  },
  {
    name: "docker-loaded",
    moduleRoot: ".coder-modules/coder/t3code",
    template: resolve(
      import.meta.dir,
      "../../../../docker-loaded/modules/t3code/scripts/install.sh.tftpl",
    ),
  },
] as const;

const runScript = async (script: string, home: string) => {
  const child = Bun.spawn(["bash", script], {
    env: { ...process.env, HOME: home },
    stdout: "pipe",
    stderr: "pipe",
  });
  const [exitCode, stdout, stderr] = await Promise.all([
    child.exited,
    new Response(child.stdout).text(),
    new Response(child.stderr).text(),
  ]);
  return { exitCode, stdout, stderr };
};

describe("T3 Code latest-version upgrades", () => {
  for (const variant of variants) {
    it(`${variant.name} upgrades stale latest installs and remains idempotent`, async () => {
      const root = await mkdtemp(join(tmpdir(), `t3code-${variant.name}-`));

      try {
        const home = join(root, "home");
        const moduleRoot = join(home, variant.moduleRoot);
        const nodeHome = join(moduleRoot, "node");
        const runtimeDir = join(moduleRoot, "runtime");
        const officialPackage = join(runtimeDir, "node_modules/t3");
        const fixedPackage = join(runtimeDir, "node_modules/@k-kit/t3code");
        const binDir = join(runtimeDir, "node_modules/.bin");
        const nodePty = join(runtimeDir, "node_modules/node-pty");
        const npmCalls = join(root, "npm-calls.log");
        const scriptPath = join(root, "install.sh");

        await mkdir(join(nodeHome, "bin"), { recursive: true });
        await mkdir(officialPackage, { recursive: true });
        await mkdir(binDir, { recursive: true });
        await mkdir(nodePty, { recursive: true });
        await symlink(nodeExecutable, join(nodeHome, "bin/node"));

        await writeFile(
          join(officialPackage, "package.json"),
          '{"version":"0.0.28"}\n',
        );
        await writeFile(join(nodePty, "index.js"), "module.exports = {};\n");
        await writeFile(join(binDir, "t3"), "#!/usr/bin/env bash\nexit 0\n");
        await chmod(join(binDir, "t3"), 0o755);

        await writeFile(
          join(nodeHome, "bin/curl"),
          `#!/usr/bin/env bash\nprintf '%s' '${releaseUrl}'\n`,
        );
        await chmod(join(nodeHome, "bin/curl"), 0o755);

        await writeFile(
          join(nodeHome, "bin/npm"),
          `#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> '${npmCalls}'
mkdir -p '${fixedPackage}' '${binDir}'
printf '%s\n' '{"version":"${fixedVersion}"}' > '${join(fixedPackage, "package.json")}'
printf '%s\n' '#!/usr/bin/env bash' 'exit 0' > '${join(binDir, "t3")}'
chmod +x '${join(binDir, "t3")}'
`,
        );
        await chmod(join(nodeHome, "bin/npm"), 0o755);

        const template = await readFile(variant.template, "utf8");
        const rendered = template
          .replace("${ARG_NODE_VERSION}", nodeVersion)
          .replace("${ARG_T3CODE_VERSION}", "latest")
          .replaceAll("$${", "${")
          .replaceAll("%%{", "%{");
        await writeFile(scriptPath, rendered);
        await chmod(scriptPath, 0o755);

        const first = await runScript(scriptPath, home);
        expect(first.exitCode, first.stderr).toBe(0);
        expect(first.stdout).toContain(
          `Installing https://github.com/K-Kit/t3code/releases/download/v${fixedVersion}/k-kit-t3code-${fixedVersion}.tgz`,
        );
        expect(first.stdout).toContain(
          `Installed T3 Code ${fixedVersion} successfully.`,
        );

        const firstCalls = await readFile(npmCalls, "utf8");
        expect(firstCalls).toContain("--allow-remote=root");
        expect(firstCalls).toContain(`k-kit-t3code-${fixedVersion}.tgz`);

        const second = await runScript(scriptPath, home);
        expect(second.exitCode, second.stderr).toBe(0);
        expect(second.stdout).toContain(
          `T3 Code ${fixedVersion} is already installed`,
        );
        expect(await readFile(npmCalls, "utf8")).toBe(firstCalls);
      } finally {
        await rm(root, { recursive: true, force: true });
      }
    });
  }

  const liveTest = process.env.T3CODE_LIVE_PACKAGE_TEST === "1" ? it : it.skip;

  liveTest(
    "upgrades a real t3@0.0.28 install from the public release",
    async () => {
      if (npmExecutable === null) {
        throw new Error("npm is required for the live T3 Code package test");
      }

      const root = await mkdtemp(join(tmpdir(), "t3code-live-upgrade-"));

      try {
        const home = join(root, "home");
        const moduleRoot = join(home, ".coder-modules/coder/t3code");
        const nodeHome = join(moduleRoot, "node");
        const runtimeDir = join(moduleRoot, "runtime");
        const scriptPath = join(root, "install.sh");

        await mkdir(join(nodeHome, "bin"), { recursive: true });
        await mkdir(runtimeDir, { recursive: true });
        await symlink(nodeExecutable, join(nodeHome, "bin/node"));
        await symlink(npmExecutable, join(nodeHome, "bin/npm"));
        await writeFile(
          join(runtimeDir, "package.json"),
          '{"name":"coder-t3code-runtime","private":true,"allowScripts":{"node-pty":true,"msgpackr-extract":true}}\n',
        );

        const seed = Bun.spawn(
          [
            npmExecutable,
            "install",
            "--prefix",
            runtimeDir,
            "--no-save",
            "--package-lock=false",
            "--omit=dev",
            "--no-audit",
            "--no-fund",
            "t3@0.0.28",
          ],
          {
            env: { ...process.env, npm_config_cache: join(root, "npm-cache") },
            stdout: "pipe",
            stderr: "pipe",
          },
        );
        const [seedExit, seedStdout, seedStderr] = await Promise.all([
          seed.exited,
          new Response(seed.stdout).text(),
          new Response(seed.stderr).text(),
        ]);
        expect(seedExit, `${seedStdout}\n${seedStderr}`).toBe(0);

        const template = await readFile(variants[0].template, "utf8");
        const rendered = template
          .replace("${ARG_NODE_VERSION}", nodeVersion)
          .replace("${ARG_T3CODE_VERSION}", "latest")
          .replaceAll("$${", "${")
          .replaceAll("%%{", "%{");
        await writeFile(scriptPath, rendered);
        await chmod(scriptPath, 0o755);

        const first = await runScript(scriptPath, home);
        expect(first.exitCode, first.stderr).toBe(0);
        expect(first.stdout).toContain(
          `Installed T3 Code ${fixedVersion} successfully.`,
        );

        const packageJson = JSON.parse(
          await readFile(
            join(runtimeDir, "node_modules/@k-kit/t3code/package.json"),
            "utf8",
          ),
        ) as { version: string; gitHead: string };
        expect(packageJson.version).toBe(fixedVersion);
        expect(packageJson.gitHead).toBe(
          "7c84ad2cb3da3e78ee578a14fce4bf2f97e138fb",
        );
        expect(
          await Bun.file(
            join(runtimeDir, "node_modules/t3/package.json"),
          ).exists(),
        ).toBe(false);

        const second = await runScript(scriptPath, home);
        expect(second.exitCode, second.stderr).toBe(0);
        expect(second.stdout).toContain(
          `T3 Code ${fixedVersion} is already installed`,
        );
      } finally {
        await rm(root, { recursive: true, force: true });
      }
    },
    120_000,
  );
});
