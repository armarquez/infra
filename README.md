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

Create a `proxmox-ve` Incus image

- Must install `distrobuilder`
- Must install `just`

### Initial Setup

`just setup HOST`

## Incus Testing

### Setup

1. Follow [Incus *Getting Started* docs](https://linuxcontainers.org/incus/docs/main/tutorial/first_steps/)
2. Ensure Docker is not installed as it can mess up networking.

### Images

1. Create VM images if they don't exist for OS. Followed [blog post](https://discussion.scottibyte.com/t/incus-virtual-machine-custom-installation/407) and [Incus documentation](https://linuxcontainers.org/incus/docs/main/howto/instances_create/#launch-a-vm-that-boots-from-an-iso)
2. Enable `cloud-init` for VMs to easily configure test instances. Followed [blog post](https://www.learnlinux.tv/getting-started-with-cloud-init/)

### Configure Incus

1. Create profile to allow SSH access to Incus instances. Based upon [the following blog](https://discussion.scottibyte.com/t/incus-ssh-keys-how-to-use-yubico-hardware-keys-with-incus/421)

    ```bash
    incus profile create bridgeprofile
    incus profile device add bridgeprofile eth0 nic nictype=bridged parent=bridge0
    ````
2. Apply profile to instance ([docs](https://linuxcontainers.org/incus/docs/main/profiles/#apply-a-profile-to-an-instance))

    ```bash
    incus profile add <instance_name> <profile_name>
    ```