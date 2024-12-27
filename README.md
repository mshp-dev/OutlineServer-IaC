# Deploy an outline server with terraform on aws ec2 instance

* The main branch of this Repository represents the steps have been taken to deploy outline server with terraform on aws ec2.

## Prerequisties
### Install required cli tools
  - aws cli
    ```bash
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip awscliv2.zip
    ./aws/install
    ## confirming aws cli install
    ```
  - terraform
    ```bash
    wget -O - https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/hashicorp.list
    apt update && apt install -y terraform
    ## confirming argocd install
    terraform version
    ```
  - ansible
    ```bash
    apt install software-properties-common ca-certificates curl gnupg gpg python3-pip python3-dev
    add-apt-repository --yes --update ppa:ansible/ansible
    apt update && apt install -y ansible
    ## confirming ansible install
    ansible --version
    ```

## Steps should be taken
### 1. Creating VMs with Terraform
- #### Here are the resources should be provisioned with terraform to have a working cluster with three nodes
  * Add these provider to main.tf
    ```terraform
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
    ```
    and run the following command:
    ```bash
    terraform init
    ```
  * Create the VPC with aws_vpc resource
  * Create a public subnet
  * Create an internet gateway and attach it to the VPC
  * Create a route table (0.0.0.0/0 to -> IGW) and attach it to the subnet
  * Create a security group to open all inbounds and outbounds ports
  * Create one node with aws_instance resource inside the subnet and attach the security groups to them
    * Create a private key first
    * Create a key pair and output the private key locally
    * Create the ec2 instance
  * Create the ansible hosts ansible_host resource

  ```bash
  ansible-galaxy collection install cloud.terraform
  terraform validate
  terraform plan
  terraform apply
  ```

### 2. Install outline server with Ansible
- #### The playbook.yml contains necessary tasks for setup the kubernetes cluster on newly provioned aws ec2 isntances
  ```bash
  ansible-playbook -i inventory.yml playbook.yml
  ```
