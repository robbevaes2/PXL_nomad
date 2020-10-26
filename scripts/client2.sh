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