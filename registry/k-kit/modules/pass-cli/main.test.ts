import { beforeAll, describe, expect, setDefaultTimeout, test } from "bun:test";
import {
  executeScriptInContainer,
  runTerraformApply,
  runTerraformInit,
  testRequiredVariables,
} from "~test";

setDefaultTimeout(120_000);

const before = String.raw`
mkdir -p /usr/local/bin

cat > /usr/local/bin/coder <<'SCRIPT'
#!/bin/sh
exit 0
SCRIPT
chmod +x /usr/local/bin/coder

cat > /usr/local/bin/jq <<'SCRIPT'
#!/bin/sh
exit 0
SCRIPT
chmod +x /usr/local/bin/jq

cat > /usr/local/bin/curl <<'SCRIPT'
#!/bin/sh
cat <<'INSTALLER'
#!/bin/bash
set -e
mkdir -p "$PROTON_PASS_CLI_INSTALL_DIR"
cat > "$PROTON_PASS_CLI_INSTALL_DIR/pass-cli" <<'CLI'
#!/bin/bash
case "$1" in
  --version)
    echo "pass-cli 9.9.9"
    ;;
  info)
    exit 1
    ;;
  login)
    echo "logged in"
    ;;
  *)
    exit 2
    ;;
esac
CLI
chmod +x "$PROTON_PASS_CLI_INSTALL_DIR/pass-cli"
INSTALLER
SCRIPT
chmod +x /usr/local/bin/curl
`;

describe("pass-cli", () => {
  beforeAll(async () => {
    await runTerraformInit(import.meta.dir);
  });

  testRequiredVariables(import.meta.dir, {
    agent_id: "test-agent",
  });

  test("runs the install pipeline", async () => {
    const state = await runTerraformApply(import.meta.dir, {
      agent_id: "test-agent",
      install_dir: "/tmp/pass-cli-bin",
    });

    const result = await executeScriptInContainer(
      state,
      "debian:bookworm-slim",
      "bash",
      before,
    );
    const output = [...result.stdout, ...result.stderr].join("\n");

    expect(result.exitCode).toBe(0);
    expect(output).toContain("Proton Pass CLI version: pass-cli 9.9.9");
    expect(output).toContain("Run 'pass-cli login' to authenticate");
  });
});
