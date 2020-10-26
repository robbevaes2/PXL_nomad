	# -*- mode: ruby -*-
# vi: set ft=ruby :


VAGRANTFILE_API_VERSION = "2"
Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|

config.vm.define "server" do |server|
  server.vm.hostname = "server"
  server.vm.provision "shell", path: "scripts/server.sh"
  server.vm.network "private_network", ip:"192.168.1.2", type: "static"
  server.vm.network "forwarded_port", guest: 4646, host: 4646, auto_correct: true, host_ip: "127.0.0.1"
  server.vm.network "forwarded_port", guest: 8500, host: 8500, auto_correct: true, host_ip: "127.0.0.1"
end

config.vm.define "client1" do |client1|
  client1.vm.hostname = "client1"
  client1.vm.provision "shell", path: "scripts/client1.sh"
  client1.vm.network "private_network", ip:"192.168.1.3", type: "static"
end

config.vm.define "client2" do |client2|
  client2.vm.hostname = "client2"
  client2.vm.provision "shell", path: "scripts/client2.sh"
  client2.vm.network "private_network", ip:"192.168.1.4", type: "static"
end

  config.vm.provider :virtualbox do |virtualbox, override|
    virtualbox.customize ["modifyvm", :id, "--memory", 2048]
  end
  
	config.vm.box = "centos/7"
	config.vm.provision "shell", path: "scripts/install.sh"
end
