# armarquez/infra

This repo is for code that helps to deploy my home infrastructure.
It uses Ansible and Terraform for the configuration of servers and
clients.

Heavily based upon: https://github.com/ironicbadger/infra

where:

| Ironic Badger Machine | My Machine |
|-----------------------|------------|
| `morpheus`            | `phoenix`  |
| `elrond`              | `cerebro`  |
| `pennywise`           | `dazzler`  |

## Prerequisites

Create a `proxmox-ve` Vagrant Base Box utilizing this git repo: https://github.com/rgl/proxmox-ve

- Must install `packer`