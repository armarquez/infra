#!/usr/bin/env bash
set -euo pipefail

echo "Initializing Packer plugins..."
packer init .

echo "Validating Packer template..."
packer validate .

echo "Configuration is valid."

