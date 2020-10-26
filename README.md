<h1> Groep 2 - Linux PE Documentatie <h1>
<h2> Installatie en Configruatie <h2>

Met het volgende commando worden er 1 server en 2 client Virtuele machine's opgestart
```
$ vagrant up
```

Aan de hand van volgende vagrant file worden deze VM's opgestart:
**VagrantFile**
```
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
```

In de Vagrantfile gebeurd het volgende:

Er worden 2 clients en 1 server aangemaakt. Deze krijgen een hostname en draaien op centos/7. Op al de VM's wordt ```install.sh```(zie volgend onderdeel) uitgevoerd. 
Ook worden de individuele scripts voor de server ```server.sh```, client1 ```client1.sh``` en client2 ```client2.sh``` uitgevoerd.
Er worden ook steeds statische ip's toegekend aan de VM's, dit doet we omdat elke VM anders hetzelfde ip krijgt.

**Install.sh**
```
#!/bin/bash

availableUpdates=$(sudo yum -q check-update | wc -l)

if [ $availableUpdates -gt 0 ]; then
    sudo yum upgrade -y;
else
    echo $availableUpdates "updates available"
fi

sudo yum -y install yum-utils
sudo yum-config-manager --add-repo https://rpm.releases.hashicorp.com/RHEL/hashicorp.repo
sudo yum -y install docker
sudo yum -y install nomad
sudo yum -y install consul

sudo systemctl enable docker
sudo systemctl start docker
```

Het script ```install.sh``` zorgt ervoor dat er eventuele Linux updates gedaan worden. Ook worden Docker, Nomad en Consul geinstalleerd.

Wanneer deze geinstalleerd zijn wordt per Virtuele Machine een apart script gerunt. Deze zorgt ervoor dat de server/client geconfigureerd wordt.

**Server Script***
```
$! /bin/bash

#Nomad Config
sudo sed -i '4s/.*/bind_addr = "192.168.1.2"/' /etc/nomad.d/nomad.hcl

#Consul Config
sudo sed -i '25s/.*/bind_addr = "192.168.1.2"/' /etc/consul.d/consul.hcl
sudo sed -i '40s/.*/server = true/' /etc/consul.d/consul.hcl
sudo sed -i '49s/.*/bootstrap_expect=1/' /etc/consul.d/consul.hcl

sudo sed -i '$ a export NOMAD_ADDR=http://192.168.1.2:4646' .bashrc

sudo systemctl enable nomad
sudo systemctl enable consul
sudo systemctl start nomad
sudo systemctl start consul
``` 

Als eerste gaan we de nomand file aanpassen zodat we hier het bind address kunnen instellen. 
Hierna gaan we de Consul file aanpassen. Hier herkennen we eerst ook het bind address aan toe. We zetten de server op true, zodat deze herkent wordt als consul server.
We doen een NOMAD_ADDR naar de bashrc zodat we niet steeds de addres-tag moeten meegeven bij het nomad command.
tot slot enabelen en starten we de nomad en consul.

**Client Scripts**
```
$! /bin/bash

sudo sed -i '4s/.*/bind_addr = "192.168.1.4"/' /etc/nomad.d/nomad.hcl
sudo sed -i '7s/.*/enabled = false/' /etc/nomad.d/nomad.hcl
sudo sed -i '13s/.*/servers = ["192.168.1.2:4647"]/' /etc/nomad.d/nomad.hcl

sudo sed -i '25s/.*/bind_addr = "192.168.1.4"/' /etc/consul.d/consul.hcl
sudo sed -i '73s/.*/retry_join = ["192.168.1.2"]/' /etc/consul.d/consul.hcl

sudo systemctl enable nomad
sudo systemctl enable consul
sudo systemctl start nomad
sudo systemctl start consul
```

Eerst stellen we het bind address van de client in voor nomad. Hierna stellen we in dat de client geen server is.
De volgende regel zorgt ervoor dat de client weet naar welke server hij moet luisteren.
We stellen ook het bind address in voor nomad. Als dit de eerste keer niet lukt blijft hij dit proberen tot dit wel lukt.
Ook worden weer nomad en cosul geenabeld en gestart.



















































