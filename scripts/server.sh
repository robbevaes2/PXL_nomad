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
