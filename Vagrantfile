# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  # Base VM OS configuration.
  config.vm.synced_folder ".", "/vagrant", disabled: true
  config.ssh.insert_key = false
  config.ssh.forward_agent = true
  
  # General VirtualBox VM configuration.
  config.vm.provider :virtualbox do |vb|
    vb.linked_clone = true
    vb.memory = "512"
    vb.cpus = "1"
  end

  # VM specific configs.
  # Cerebro.
  # config.vm.define "cerebro" do |cerebro|
  #   cerebro.vm.box = "bento/ubuntu-20.04"
  #   cerebro.vm.hostname = "cerebro.test"
  #   cerebro.vm.network :private_network, ip: "192.168.60.250"
  # end

  # Phoenix.
  config.vm.define "phoenix" do |phoenix|
    phoenix.vm.box = "proxmox-ve-amd64"
    phoenix.vm.hostname = "phoenix.test"
    phoenix.vm.network :private_network, ip: "192.168.60.240"
  end

  # Dazzler
  config.vm.define "dazzler" do |dazzler|
    dazzler.vm.box = "bento/ubuntu-20.04"
    dazzler.vm.hostname = "dazzler.test"
    dazzler.vm.network :private_network, ip: "192.168.60.241"

    # Run Ansible provisioner once for all VMs at the end.
    dazzler.vm.provision "ansible" do |ansible|
      ansible.playbook = "run.yaml"
      ansible.inventory_path = "inventories/vagrant/inventory"
      ansible.limit = "all"
      ansible.verbose = "-vvvv"
      ansible.extra_vars = {
        ansible_user: 'vagrant',
        ansible_ssh_private_key_file: "~/.vagrant.d/insecure_private_key",
      }
    end
  end
end
