#!/usr/bin/env -S just --justfile
# ^ A shebang isn't required, but allows a justfile to be executed
#   like a script, with `./justfile test`, for example.

#alias t := test

#alias c := check

bt := '0'

export RUST_BACKTRACE := bt

log := "warn"

export JUST_LOG := log

# List recipes by default
default:
  just --list

# Run defined Ansible playbook for HOST
run HOST *TAGS:
  ansible-playbook -b run.yaml --limit {{HOST}} {{TAGS}}

## repo stuff
# install requirements
reqs *FORCE:
	ansible-galaxy install -r requirements.yaml {{FORCE}}

# perform an action (encrypt/decrypt/edit) on Ansible vault
vault ACTION:
    EDITOR='code --wait' ansible-vault {{ACTION}} vars/vault.yaml

