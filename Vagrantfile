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
    vb.memory = "1024"
    vb.cpus = "1"
  end

  # VM specific configs.
  # Cerebro.
  # config.vm.define "cerebro" do |cerebro|
  #   cerebro.vm.box = "bento/ubuntu-20.04"
  #   cerebro.vm.hostname = "cerebro.test"
  #   cerebro.vm.network :private_network, ip: "192.168.60.200"
  # end

  # Phoenix.
  config.vm.define "phoenix" do |phoenix|
    phoenix.vm.box = "proxmox-ve-amd64"
    phoenix.vm.hostname = "phoenix.test"
    phoenix.vm.network :private_network, ip: "192.168.60.201"

    # Run Ansible provisioner once for all VMs at the end.
    phoenix.vm.provision "ansible" do |ansible|
      ansible.playbook = "ansible/run.yaml"
      ansible.config_file = "ansible/ansible.cfg"
      ansible.inventory_path = "ansible/inventories/vagrant/inventory"
      ansible.galaxy_roles_path = "ansible/galaxy_roles"
      ansible.limit = "all"
      ansible.verbose = "-vvvv"
      ansible.extra_vars = {
        ansible_user: 'vagrant',
        ansible_ssh_private_key_file: "~/.vagrant.d/insecure_private_key",
      }
    end
  end
end
