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
resource "aws_vpc" "outline_vpc" {
  cidr_block         = "10.0.0.0/16"
  enable_dns_support = true

  tags = {
    Name = "vpc_${var.name_postfix}"
  }
}

## 2. subnet
resource "aws_subnet" "outline_subnet" {
  vpc_id                  = aws_vpc.outline_vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true

  tags = {
    Name = "subnet_${var.name_postfix}"
  }
}

## 3. internet gateway
resource "aws_internet_gateway" "outline_internet_gateway" {
  vpc_id = aws_vpc.outline_vpc.id

  tags = {
    Name = "igw_${var.name_postfix}"
  }
}

## 4. custom route table
resource "aws_route_table" "outline_route_table" {
  vpc_id = aws_vpc.outline_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.outline_internet_gateway.id
  }

  tags = {
    Name = "rt_${var.name_postfix}"
  }
}

## 5. associate the route table to the subnet
resource "aws_route_table_association" "outline_rt_assc" {
  subnet_id      = aws_subnet.outline_subnet.id
  route_table_id = aws_route_table.outline_route_table.id
}

## 6. create security groups
resource "aws_security_group" "outline_security_group_common" {
  name        = "sg_common_${var.name_postfix}"
  description = "Allow All inbound traffic and all outbound traffic"
  vpc_id      = aws_vpc.outline_vpc.id

  ingress {
    description = "Allow All"
    protocol    = "tcp"
    from_port   = 0
    to_port     = 65535
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

## 7. create instances for k8s cluster
### 1. create key-pair for password-less ssh
resource "tls_private_key" "outline_ssh_rsa_private_key" {
  algorithm = "RSA"
  rsa_bits  = 4096

  provisioner "local-exec" {
    command = "echo '${self.public_key_pem}' > ./files/outline_rsa.pub"
  }
}
resource "aws_key_pair" "outline_ssh_keypair" {
  key_name   = var.ssh_key_pair_name
  public_key = tls_private_key.outline_ssh_rsa_private_key.public_key_openssh

  provisioner "local-exec" {
    command = "echo '${tls_private_key.outline_ssh_rsa_private_key.private_key_pem}' > ./files/outline_rsa"
  }

  provisioner "local-exec" {
    command = "chmod 400 ./files/outline_rsa"
  }
}
### 2. create 1/one ec2 instance to play as k8s control plane
resource "aws_instance" "outline_server_ec2" {
  ami                         = var.ubuntu_ami
  instance_type               = "t2.micro"
  key_name                    = aws_key_pair.outline_ssh_keypair.key_name
  subnet_id                   = aws_subnet.outline_subnet.id
  associate_public_ip_address = true

  vpc_security_group_ids = [
    aws_security_group.outline_security_group_common.id,
  ]

  root_block_device {
    volume_type = "gp3"
    volume_size = 10
  }

  tags = {
    Name = "ec2_${var.name_postfix}"
    Role = "server"
  }

  provisioner "local-exec" {
    command = "echo 'outline-server ${self.public_ip}' >> ./files/hosts"
  }
}

## 8. create host inventory for k8s control plane and worker nodes
resource "ansible_host" "outline_server_host" {
  depends_on = [
    aws_instance.outline_server_ec2
  ]

  name   = "outline_server"
  groups = ["servers"]

  variables = {
    ansible_user                 = "ubuntu"
    ansible_host                 = aws_instance.outline_server_ec2.public_ip
    ansible_ssh_private_key_file = "./files/outline_rsa"
    node_hostname                = "outline_server"
  }
}

