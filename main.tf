terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.80.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "4.0.6"
    }
    ansible = {
      source  = "ansible/ansible"
      version = "1.3.0"
    }
  }
}

provider "aws" {
  # access_key = "$AWS_ACCESS_KEY"
  # secret_key = "$AWS_SECRET_KEY"
  region = var.aws_region
}

## 1. custom VPC
resource "aws_vpc" "arvan_sre_vpc" {
  cidr_block         = "10.0.0.0/16"
  enable_dns_support = true

  tags = {
    Name = "vpc_${var.name_postfix}"
  }
}

## 2. subnet
resource "aws_subnet" "arvan_sre_subnet" {
  vpc_id                  = aws_vpc.arvan_sre_vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true

  tags = {
    Name = "subnet_${var.name_postfix}"
  }
}

## 3. internet gateway
resource "aws_internet_gateway" "arvan_sre_internet_gateway" {
  vpc_id = aws_vpc.arvan_sre_vpc.id

  tags = {
    Name = "igw_${var.name_postfix}"
  }
}

## 4. custom route table
resource "aws_route_table" "arvan_sre_route_table" {
  vpc_id = aws_vpc.arvan_sre_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.arvan_sre_internet_gateway.id
  }

  tags = {
    Name = "rt_${var.name_postfix}"
  }
}

## 5. associate the route table to the subnet
resource "aws_route_table_association" "arvan_sre_rt_assc" {
  subnet_id      = aws_subnet.arvan_sre_subnet.id
  route_table_id = aws_route_table.arvan_sre_route_table.id
}

## 6. create security groups
### 1. common ports (ssh/http/https)
resource "aws_security_group" "arvan_sre_security_group_common" {
  name        = "sg_common_${var.name_postfix}"
  description = "Allow SSH/HTTP/HTTPS inbound traffic and all outbound traffic"
  vpc_id      = aws_vpc.arvan_sre_vpc.id

  ingress {
    description = "Allow SSH"
    protocol    = "tcp"
    from_port   = 22
    to_port     = 22
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow HTTP"
    protocol    = "tcp"
    from_port   = 80
    to_port     = 80
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow HTTPS"
    protocol    = "tcp"
    from_port   = 443
    to_port     = 443
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "sg_common_${var.name_postfix}"
  }
}
### 2. k8s control-plane ports
resource "aws_security_group" "arvan_sre_security_group_k8s_control_plane" {
  name        = "sg_k8s_cp_${var.name_postfix}"
  description = "K8S Control Plane Security Group"
  vpc_id      = aws_vpc.arvan_sre_vpc.id

  ingress {
    description = "Kubernetes API Server"
    protocol    = "tcp"
    from_port   = 6443
    to_port     = 6443
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Etcd server client API"
    protocol    = "tcp"
    from_port   = 2379
    to_port     = 2380
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Kubelet API"
    protocol    = "tcp"
    from_port   = 10250
    to_port     = 10250
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Kube Scheduler"
    protocol    = "tcp"
    from_port   = 10259
    to_port     = 10259
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Kube Contoller Manager"
    protocol    = "tcp"
    from_port   = 10257
    to_port     = 10257
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "sg_k8s_cp_${var.name_postfix}"
  }
}
### 3. k8s worker-node ports
resource "aws_security_group" "arvan_sre_security_group_k8s_worker_nodes" {
  name        = "sg_k8s_wn_${var.name_postfix}"
  description = "K8S Worker Nodes Security Group"
  vpc_id      = aws_vpc.arvan_sre_vpc.id

  ingress {
    description = "Kubelet API"
    protocol    = "tcp"
    from_port   = 10250
    to_port     = 10250
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Kube Proxy"
    protocol    = "tcp"
    from_port   = 10256
    to_port     = 10256
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "NodePort Servicest"
    protocol    = "tcp"
    from_port   = 30000
    to_port     = 32767
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "sg_k8s_wn_${var.name_postfix}"
  }
}
### 4. k8s flannel UDP backend ports
resource "aws_security_group" "arvan_sre_security_group_k8s_flannel" {
  name        = "sg_k8s_flnl_${var.name_postfix}"
  description = "K8S Flannel Overlay backend"
  vpc_id      = aws_vpc.arvan_sre_vpc.id

  ingress {
    description = "flannel overlay backend"
    protocol    = "udp"
    from_port   = 8285
    to_port     = 8285
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "flannel vxlan backend"
    protocol    = "udp"
    from_port   = 8472
    to_port     = 8472
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "sg_k8s_flnl_${var.name_postfix}"
  }
}

## 7. create instances for k8s cluster
### 1. create key-pair for password-less ssh
resource "tls_private_key" "arvan_sre_ssh_rsa_private_key" {
  algorithm = "RSA"
  rsa_bits  = 4096

  provisioner "local-exec" {
    command = "echo '${self.public_key_pem}' > ./files/arvan_sre_rsa.pub"
  }
}
resource "aws_key_pair" "arvan_sre_ssh_keypair" {
  key_name   = var.ssh_key_pair_name
  public_key = tls_private_key.arvan_sre_ssh_rsa_private_key.public_key_openssh

  provisioner "local-exec" {
    command = "echo '${tls_private_key.arvan_sre_ssh_rsa_private_key.private_key_pem}' > ./files/arvan_sre_rsa"
  }
}
### 2. create 1/one ec2 instance to play as k8s control plane
resource "aws_instance" "arvan_sre_ec2_k8s_master" {
  ami                         = var.ubuntu_ami
  instance_type               = "t2.medium"
  key_name                    = aws_key_pair.arvan_sre_ssh_keypair.key_name
  subnet_id                   = aws_subnet.arvan_sre_subnet.id
  associate_public_ip_address = true

  vpc_security_group_ids = [
    aws_security_group.arvan_sre_security_group_common.id,
    aws_security_group.arvan_sre_security_group_k8s_control_plane.id,
    aws_security_group.arvan_sre_security_group_k8s_flannel.id,
  ]

  root_block_device {
    volume_type = "gp3"
    volume_size = 14
  }

  tags = {
    Name = "ec2_k8s_master_${var.name_postfix}"
    Role = "control_plane, master"
  }

  provisioner "local-exec" {
    command = "echo 'master ${self.public_ip}' >> ./files/hosts"
  }
}
### 3. create 2/two ec2 instances to play as k8s worker nodes
resource "aws_instance" "arvan_sre_ec2_k8s_workers" {
  count                       = var.worker_counts
  ami                         = var.ubuntu_ami
  instance_type               = "t2.micro"
  key_name                    = aws_key_pair.arvan_sre_ssh_keypair.key_name
  subnet_id                   = aws_subnet.arvan_sre_subnet.id
  associate_public_ip_address = true

  vpc_security_group_ids = [
    aws_security_group.arvan_sre_security_group_common.id,
    aws_security_group.arvan_sre_security_group_k8s_worker_nodes.id,
    aws_security_group.arvan_sre_security_group_k8s_flannel.id,
  ]

  root_block_device {
    volume_type = "gp3"
    volume_size = 8
  }

  tags = {
    Name = "ec2_k8s_worker_${count.index}_${var.name_postfix}"
    Role = "worker"
  }

  provisioner "local-exec" {
    command = "echo 'worker-${count.index} ${self.public_ip}' >> ./files/hosts"
  }
}

## 8. create host inventory for k8s control plane and worker nodes
resource "ansible_host" "arvan_sre_control_plane_host" {
  depends_on = [
    aws_instance.arvan_sre_ec2_k8s_master
  ]

  name   = "control_plane"
  groups = ["master"]

  variables = {
    ansible_user                 = "ubuntu"
    ansible_host                 = aws_instance.arvan_sre_ec2_k8s_master.public_ip
    ansible_ssh_private_key_file = "./files/arvan_sre_rsa"
    node_hostname                = "master"
  }
}
resource "ansible_host" "arvan_sre_worker_nodes_host" {
  depends_on = [
    aws_instance.arvan_sre_ec2_k8s_workers
  ]

  count  = var.worker_counts
  name   = "worker-${count.index}"
  groups = ["workers"]

  variables = {
    node_hostname                = "worker-${count.index}"
    ansible_user                 = "ubuntu"
    ansible_host                 = aws_instance.arvan_sre_ec2_k8s_workers[count.index].public_ip
    ansible_ssh_private_key_file = "./files/arvan_sre_rsa"
  }
}

# output "instances" {
#   value = data.arvan_abraks.instance_list.instances
# }
