default:
  just --list

# Detect OS for package installation
detect-os:
  #!/usr/bin/env bash
  unameOut="$(uname -s)"
  case "${unameOut}" in
      Linux*)     os=linux;;
      Darwin*)    os=macos;;
      *)          os="unknown"
  esac
  echo "Detected OS: $os"

# Install all system-level dependencies
bootstrap:
  just install-direnv
  just install-mise
  just info-bootstrap

# Install direnv
install-direnv:
  #!/usr/bin/env bash
  if ! command -v direnv >/dev/null; then
    os=$(just --quiet detect-os)
    if [[ "$os" == "Detected OS: macos" ]]; then
      brew install direnv
    elif [[ "$os" == "Detected OS: linux" ]]; then
      sudo apt install direnv -y
    else
      echo "❌ Unsupported OS: $os"
      exit 1
    fi
    # TODO: add remaining steps of direnv install
  else
    echo "✅ direnv is already installed"
    exit 0
  fi

# Install mise (repo toolchain pinned in ./mise.toml — just, opentofu, yq)
install-mise:
  #!/usr/bin/env bash
  if ! command -v mise >/dev/null; then
    os=$(just --quiet detect-os)
    if [[ "$os" == "Detected OS: macos" ]]; then
      brew install mise
    elif [[ "$os" == "Detected OS: linux" ]]; then
      curl -fsSL https://mise.run | sh
    else
      echo "❌ Unsupported OS: $os"
      exit 1
    fi
    echo "✅ mise installed."
    echo "   Add this to your shell rc (~/.zshrc or ~/.bashrc):"
    echo "     eval \"\$(mise activate zsh)\"   # or bash"
  else
    echo "✅ mise is already installed"
  fi

# Nice info after bootstrap
info-bootstrap:
  @echo ""
  @echo "🎉 Bootstrap complete!"
  @echo "Next steps:"
  @echo "  1. Restart your shell (or source ~/.zshrc / ~/.bashrc)"
  @echo "  2. Run 'direnv allow' in the project directory"
  @echo "  3. Run 'mise install' to install pinned toolchain (just, tofu, yq)"
  @echo "  4. Run 'just ansible install' to set up the Python/Ansible venv"
  @echo "     (provides ansible-vault used by 'just terraform apply' bridge)"
  @echo "  5. Run 'just ansible install-op-vault' to install the 1P vault helper"
  @echo "  6. Run 'just install-hooks' to install git pre-commit hooks"
  @echo ""

# Install git pre-commit hooks into .git/hooks/ (run once after cloning; requires: just ansible install)
install-hooks:
  direnv exec ./ansible pre-commit install

# Run pre-commit checks against all files (useful after updating hooks)
lint-all:
  direnv exec ./ansible pre-commit run --all-files

# Routing
ansible *ARGS:
  direnv exec ./ansible just --justfile ansible/justfile {{ARGS}}

terraform *ARGS:
  direnv exec ./terraform just --justfile terraform/justfile {{ARGS}}

incus *ARGS:
  direnv exec ./incus just --justfile incus/justfile {{ARGS}}

images *ARGS:
  direnv exec ./images just --justfile images/justfile {{ARGS}}

# Full testing workflow: reset instance and run ansible test
test-workflow HOST *TAGS:
  #!/usr/bin/env sh
  echo "🚀 Full testing workflow for {{HOST}}"
  echo "1️⃣ Resetting instance to clean state..."
  just incus restore {{HOST}} clean
  echo "2️⃣ Running Ansible test..."
  just ansible test {{HOST}} {{TAGS}}
  echo "✅ Testing workflow complete"
