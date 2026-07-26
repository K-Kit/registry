mock_provider "coder" {}

run "defaults_install_stable_cli" {
  command = apply

  variables {
    agent_id = "test-agent"
  }

  assert {
    condition     = local.module_directory == "$HOME/.coder-modules/k-kit/pass-cli"
    error_message = "The module must use the standard per-module data root."
  }

  assert {
    condition     = strcontains(local.install_script, "ARG_INSTALL_CHANNEL='stable'")
    error_message = "The install script must default to the stable release track."
  }

  assert {
    condition     = strcontains(local.install_script, "https://proton.me/download/pass-cli/install.sh")
    error_message = "The install script must use Proton's official installer."
  }

  assert {
    condition     = strcontains(local.install_script, base64encode("$HOME/.local/bin"))
    error_message = "The install script must render the default user-local install directory."
  }

  assert {
    condition     = length(coder_env.personal_access_token) == 0
    error_message = "The token environment variable must be omitted when no token is configured."
  }

  assert {
    condition     = output.scripts == ["k-kit-pass-cli-install_script"]
    error_message = "The default coder-utils pipeline must expose only the install script."
  }
}

run "token_and_custom_pipeline" {
  command = apply

  variables {
    agent_id              = "test-agent"
    personal_access_token = "pst_test_token::key"
    install_channel       = "beta"
    install_dir           = "/opt/proton-pass/bin"
    pre_install_script    = "echo pre"
    post_install_script   = "echo post"
  }

  assert {
    condition     = coder_env.personal_access_token[0].name == "PROTON_PASS_PERSONAL_ACCESS_TOKEN"
    error_message = "The personal access token must use Proton's documented environment variable."
  }

  assert {
    condition     = coder_env.personal_access_token[0].value == "pst_test_token::key"
    error_message = "The configured personal access token must be passed to the workspace."
  }

  assert {
    condition     = strcontains(local.install_script, "ARG_INSTALL_CHANNEL='beta'")
    error_message = "The requested beta release track must be rendered into the install script."
  }

  assert {
    condition     = strcontains(local.install_script, base64encode("/opt/proton-pass/bin"))
    error_message = "The custom install directory must be encoded into the install script."
  }

  assert {
    condition     = !strcontains(local.install_script, "pst_test_token::key")
    error_message = "The personal access token must not be embedded in the rendered install script."
  }

  assert {
    condition = output.scripts == [
      "k-kit-pass-cli-pre_install_script",
      "k-kit-pass-cli-install_script",
      "k-kit-pass-cli-post_install_script",
    ]
    error_message = "The coder-utils pipeline must expose pre-install, install, and post-install scripts in order."
  }
}

run "rejects_unknown_channel" {
  command = plan

  variables {
    agent_id        = "test-agent"
    install_channel = "nightly"
  }

  expect_failures = [var.install_channel]
}

run "rejects_relative_install_dir" {
  command = plan

  variables {
    agent_id    = "test-agent"
    install_dir = "bin"
  }

  expect_failures = [var.install_dir]
}
