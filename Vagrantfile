# -*- mode: ruby -*-
# vi: set ft=ruby :

# Vagrantfile API/syntax version. Don't touch unless you know what you're doing!
VAGRANTFILE_API_VERSION = "2"

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|

  # Set the base box, hostname
  config.vm.box = "ubuntu/trusty64"
  config.vm.hostname = "laverse"

  # Set memory, number of processors here
  config.vm.provider "virtualbox" do |v|
    v.memory = 6144
    v.cpus = 2
  end

  # Run the bootstrap shell script
  config.vm.provision :shell, path: "setup/bootstrap.sh"

end
