Vagrant.configure("2") do |config|
  config.vm.box = "bento/ubuntu-20.04"
  config.vm.box_check_update = true

  # Hyper-V
  # config.vm.provider "hyperv" do |h|
  #   h.cpus = 2
  #   h.memory = 4096
  # end
  # Need to set network
  # config.vm.network "public_network", bridge: "hypervmare"
  # Disable synced folders so I don't need to set SMB creds
  # config.vm.synced_folder ".", "/vagrant", disabled: true

  # VirtualBox
  # config.vm.provider "virtualbox" do |v|
  # v.cpus = 2
  # v.memory = 4096
  # end

  # VMWare
  config.vm.provider "vmware_desktop" do |vm|
    vm.vmx["memsize"] = "4096"
    vm.vmx["numvcpus"] = "2"
  end

  # Add WireGuard config
  config.vm.provision "file", source: "wg0.conf", destination: "/home/vagrant/wg0.conf"

  # Setup WireGuard
  config.vm.provision "shell", path: "vagrant_setup_wireguard.sh"
end
