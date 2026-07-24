import { describe, expect, it } from "bun:test";

const TEMPLATE_NAMES = ["ai-dev", "aws-ai-dev", "gcp-ai-dev"] as const;
const CLOUD_TEMPLATE_NAMES = ["aws-ai-dev", "gcp-ai-dev"] as const;
const SHARED_SCRIPT_PATHS = [
  "scripts/mux-install.sh.tftpl",
  "scripts/mux-start.sh.tftpl",
  "scripts/t3code-install.sh.tftpl",
  "scripts/t3code-start.sh.tftpl",
] as const;

const readTemplateFile = (templateName: string, filePath: string) =>
  Bun.file(new URL(`../${templateName}/${filePath}`, import.meta.url)).text();

describe("AI development provisioning structure", () => {
  it("keeps shared interface scripts identical across template variants", async () => {
    // Given: Docker provides the canonical shared interface scripts.
    const canonicalScripts = await Promise.all(
      SHARED_SCRIPT_PATHS.map((filePath) =>
        readTemplateFile("ai-dev", filePath),
      ),
    );

    // When: the cloud variant scripts are read from their template roots.
    const cloudScripts = await Promise.all(
      CLOUD_TEMPLATE_NAMES.map(async (templateName) => ({
        templateName,
        scripts: await Promise.all(
          SHARED_SCRIPT_PATHS.map((filePath) =>
            readTemplateFile(templateName, filePath),
          ),
        ),
      })),
    );

    // Then: each cloud variant remains byte-identical to Docker.
    for (const variant of cloudScripts) {
      expect(variant.scripts).toEqual(canonicalScripts);
    }
  });

  for (const templateName of TEMPLATE_NAMES) {
    it(`${templateName} provisions a module-private Node runtime for Mux install`, async () => {
      // Given: the template's Terraform and Mux installer sources.
      const [mainTerraform, installScript] = await Promise.all([
        readTemplateFile(templateName, "main.tf"),
        readTemplateFile(templateName, "scripts/mux-install.sh.tftpl"),
      ]);

      // When: command positions and global-runtime probes are inspected.
      const pathSetupIndex = installScript.indexOf(
        'export PATH="$NODE_HOME/bin:$PATH"',
      );
      const npmInstallIndex = installScript.indexOf("npm install");

      // Then: Terraform supplies the runtime version and install uses it first.
      expect(mainTerraform).toMatch(
        /mux_install_script\s*=\s*templatefile\("\$\{path\.module\}\/scripts\/mux-install\.sh\.tftpl",\s*\{[^}]*ARG_NODE_VERSION\s*=\s*"24\.18\.0"[^}]*\}\)/,
      );
      expect(installScript).toContain("ARG_NODE_VERSION='${ARG_NODE_VERSION}'");
      expect(installScript).toContain('NODE_HOME="$MODULE_ROOT/node"');
      expect(installScript).toContain(
        'tar -xzf "$archive" --strip-components=1 -C "$NODE_HOME"',
      );
      expect(pathSetupIndex).toBeGreaterThan(-1);
      expect(pathSetupIndex).toBeLessThan(npmInstallIndex);
      expect(installScript).not.toContain("command -v node");
      expect(installScript).not.toContain("command -v npm");
    });

    it(`${templateName} exposes the module-private Node runtime to Mux start`, async () => {
      // Given: the template's Mux start script.
      const startScript = await readTemplateFile(
        templateName,
        "scripts/mux-start.sh.tftpl",
      );

      // When: private PATH setup and service launch positions are inspected.
      const pathSetupIndex = startScript.indexOf(
        'export PATH="$NODE_HOME/bin:$PATH"',
      );
      const serviceStartIndex = startScript.indexOf('"$MUX_BIN" server');

      // Then: the private Node runtime is selected before Mux launches.
      expect(startScript).toContain('NODE_HOME="$MODULE_ROOT/node"');
      expect(pathSetupIndex).toBeGreaterThan(-1);
      expect(pathSetupIndex).toBeLessThan(serviceStartIndex);
    });

    it(`${templateName} uses the published coder-utils contract for T3 Code and Mux`, async () => {
      // Given: the template's Terraform module declarations.
      const mainTerraform = await readTemplateFile(templateName, "main.tf");

      // When: the T3 Code and Mux module blocks are inspected.
      const interfaceModuleBlocks = ["t3code", "mux"].map(
        (moduleName) =>
          mainTerraform.match(
            new RegExp(`module "${moduleName}" \\{[\\s\\S]*?\\n\\}`),
          )?.[0] ?? "",
      );

      // Then: both interfaces use only the currently published module API.
      for (const moduleBlock of interfaceModuleBlocks) {
        expect(moduleBlock).toContain(
          'source = "registry.coder.com/coder/coder-utils/coder"',
        );
        expect(moduleBlock).toContain('version = "0.0.1"');
        expect(moduleBlock).not.toContain("sync_timeout");
      }
    });
  }

  it("requires preinstalled T3 native prerequisites without package installation", async () => {
    // Given: the shared T3 installer used by the Docker template.
    const installScript = await readTemplateFile(
      "ai-dev",
      "scripts/t3code-install.sh.tftpl",
    );

    // When: package installation and prerequisite boundaries are inspected.
    const requiredCommands = ["python3", "make", "c++"] as const;

    // Then: the installer trusts the image and fails at its command boundary.
    expect(installScript).not.toContain("apt-get");
    expect(installScript).not.toContain("install_build_tools");
    for (const command of requiredCommands) {
      expect(installScript).toContain(`require_command ${command}`);
    }
  });

  for (const templateName of CLOUD_TEMPLATE_NAMES) {
    it(`${templateName} wires conditional T3 prerequisites and allows their startup time`, async () => {
      // Given: the cloud template's Terraform configuration.
      const mainTerraform = await readTemplateFile(templateName, "main.tf");

      // When: agent and cloud-init configuration are inspected.
      const cloudInitCall =
        /templatefile\("\$\{path\.module\}\/cloud-init\/startup\.sh\.tftpl",\s*\{[\s\S]*?\}\)/;
      const renderedCloudInit = mainTerraform.match(cloudInitCall)?.[0] ?? "";

      // Then: Terraform derives the install flag from the selected interfaces.
      expect(mainTerraform).toMatch(/connection_timeout\s*=\s*900/);
      expect(renderedCloudInit).toContain(
        'ARG_INSTALL_T3CODE = tostring(contains(local.selected_interfaces, "T3 Code"))',
      );
    });

    it(`${templateName} conditionally installs bounded T3 prerequisites before agent startup`, async () => {
      // Given: the cloud bootstrap script executed as root.
      const startupScript = await readTemplateFile(
        templateName,
        "cloud-init/startup.sh.tftpl",
      );

      // When: conditional package and agent-start command ordering is inspected.
      const lines = startupScript.split("\n");
      const argumentLine = lines.findIndex((line) =>
        line.includes("ARG_INSTALL_T3CODE='${ARG_INSTALL_T3CODE}'"),
      );
      const conditionalStartLine = lines.findIndex((line) =>
        line.includes('if [ "$ARG_INSTALL_T3CODE" = "true" ]; then'),
      );
      const noninteractiveLine = lines.findIndex((line) =>
        line.includes("DEBIAN_FRONTEND=noninteractive"),
      );
      const updateLine = lines.findIndex(
        (line) =>
          line.includes("apt-get") &&
          line.includes("APT::Update::Lock::Timeout=300") &&
          line.includes("DPkg::Lock::Timeout=300") &&
          line.includes("update"),
      );
      const installLine = lines.findIndex(
        (line) =>
          line.includes("apt-get") &&
          line.includes("DPkg::Lock::Timeout=300") &&
          line.includes("install") &&
          line.includes("build-essential") &&
          line.includes("python3"),
      );
      const conditionalEndLine = lines.findIndex(
        (line, index) => index > installLine && line.trim() === "fi",
      );
      const agentStartLine = lines.findIndex((line) =>
        line.includes('exec sudo -u coder -H bash "$init_script"'),
      );

      // Then: bounded native prerequisites run only in the true branch before agent init.
      expect(argumentLine).toBeGreaterThan(-1);
      expect(conditionalStartLine).toBeGreaterThan(argumentLine);
      expect(noninteractiveLine).toBeGreaterThan(conditionalStartLine);
      expect(updateLine).toBeGreaterThan(noninteractiveLine);
      expect(installLine).toBeGreaterThan(updateLine);
      expect(conditionalEndLine).toBeGreaterThan(installLine);
      expect(agentStartLine).toBeGreaterThan(conditionalEndLine);
      expect(startupScript.match(/apt-get/g)?.length ?? 0).toBe(2);
    });
  }
});
