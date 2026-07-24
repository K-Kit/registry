mock_provider "coder" {}

run "defaults_are_secure" {
  command = apply

  variables {
    agent_id = "test-agent"
  }

  assert {
    condition     = coder_app.t3code.url == "http://localhost:3773"
    error_message = "The default app URL must use T3 Code's default port."
  }

  assert {
    condition     = coder_app.t3code.subdomain
    error_message = "T3 Code must use a Coder subdomain."
  }

  assert {
    condition     = coder_app.t3code.share == "owner"
    error_message = "T3 Code must be restricted to the workspace owner."
  }

  assert {
    condition     = one(coder_app.t3code.healthcheck).url == "http://localhost:3773/"
    error_message = "The health check must use the configured T3 Code server."
  }

  assert {
    condition     = strcontains(local.start_script, "--host 127.0.0.1")
    error_message = "The startup script must bind T3 Code to IPv4 loopback."
  }

  assert {
    condition     = !strcontains(local.start_script, "0.0.0.0")
    error_message = "The startup script must not expose T3 Code on all network interfaces."
  }

  assert {
    condition     = strcontains(local.start_script, "--auto-bootstrap-project-from-cwd")
    error_message = "The default startup script must bootstrap the configured project."
  }

  assert {
    condition     = strcontains(local.install_script, "ARG_NODE_VERSION='24.18.0'")
    error_message = "The install script must render the private Node.js version."
  }

  assert {
    condition     = local.module_directory == "$HOME/.coder-modules/coder/t3code"
    error_message = "The module must use the standard per-module data root."
  }

  assert {
    condition     = length(output.scripts) == 2
    error_message = "The coder-utils pipeline must expose install and start scripts."
  }
}

run "custom_configuration" {
  command = apply

  variables {
    agent_id               = "test-agent"
    port                   = 43124
    t3code_version         = "0.0.28"
    node_version           = "24.13.1"
    workdir                = "/home/coder/project"
    auto_bootstrap_project = false
    order                  = 7
    group                  = "AI Tools"
  }

  assert {
    condition     = coder_app.t3code.url == "http://localhost:43124"
    error_message = "The app URL must use the configured port."
  }

  assert {
    condition     = coder_app.t3code.order == 7 && coder_app.t3code.group == "AI Tools"
    error_message = "The app must preserve its configured order and group."
  }

  assert {
    condition     = strcontains(local.install_script, "ARG_T3CODE_VERSION='0.0.28'")
    error_message = "The requested T3 Code version must be rendered into the install script."
  }

  assert {
    condition     = strcontains(local.start_script, base64encode("/home/coder/project"))
    error_message = "The configured working directory must be encoded into the startup script."
  }

  assert {
    condition     = strcontains(local.start_script, "ARG_AUTO_BOOTSTRAP_PROJECT='false'")
    error_message = "The disabled project bootstrapping setting must be rendered into the startup script."
  }
}

run "rejects_low_port" {
  command = plan

  variables {
    agent_id = "test-agent"
    port     = 1023
  }

  expect_failures = [var.port]
}

run "rejects_high_port" {
  command = plan

  variables {
    agent_id = "test-agent"
    port     = 65536
  }

  expect_failures = [var.port]
}

run "rejects_invalid_t3code_version" {
  command = plan

  variables {
    agent_id       = "test-agent"
    t3code_version = "main; echo unsafe"
  }

  expect_failures = [var.t3code_version]
}

run "rejects_unpinned_node_version" {
  command = plan

  variables {
    agent_id     = "test-agent"
    node_version = "latest"
  }

  expect_failures = [var.node_version]
}
