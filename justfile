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

# Install asdf
install-asdf:
  #!/usr/bin/env bash
  if ! command -v asdf >/dev/null; then
    os=$(just --quiet detect-os)
    if [[ "$os" == "Detected OS: macos" ]]; then
      brew install asdf
    elif [[ "$os" == "Detected OS: linux" ]]; then
      # TODO: Install asdf on Linux
    else
      echo "❌ Unsupported OS: $os"
      exit 1
    fi
    # TODO: add remaining steps of asdf install
  else
    echo "✅ asdf is already installed"
    exit 0
  fi

# Nice info after bootstrap
info-bootstrap:
  @echo ""
  @echo "🎉 Bootstrap complete!"
  @echo "Next steps:"
  @echo "  1. Restart your shell (or source ~/.bashrc / ~/.zshrc)"
  @echo "  2. Run 'direnv allow' in the project directory"
  @echo ""

# Add use_python function to ~/.config/direnv/direnvrc
add-use-python-function:
  #!/usr/bin/env bash
  mkdir -p "$HOME/.config/direnv"
  DRC="$HOME/.config/direnv/direnvrc"
  if grep -q 'use_python()' "$DRC" 2>/dev/null; then
    echo "✅ 'use_python' already exists in $DRC"
    exit 0
  fi
  {
    echo ''
    echo 'use_python() {'
    echo '  local python_version=$$1'
    echo '  local venv_path=".venv"'
    echo ''
    echo '  if [[ ! -d "$$venv_path" ]]; then'
    echo '    python$$python_version -m venv "$$venv_path"'
    echo '  fi'
    echo ''
    echo '  layout python "$$venv_path"'
    echo '}'
  } >> "$DRC"
  echo "✅ 'use_python' function added to $DRC"


# Routing
ansible *ARGS:
  direnv exec ./ansible just --justfile ansible/justfile {{ARGS}}

terraform *ARGS:
  direnv exec ./terraform just --justfile terraform/justfile {{ARGS}}

incus *ARGS:
  direnv exec ./incus just --justfile incus/justfile {{ARGS}}
