variable "name_postfix" {
  type        = string
  description = "The postfix part of all objects name"
  default     = "arvan_sre"
}

variable "ssh_key_pair_name" {
  type        = string
  description = "The name of SSH key-pair"
  default     = "arvan_sre_ssh_key"
}

variable "aws_region" {
  type        = string
  description = "The AWS region"
  default     = "us-east-1"
}

variable "ubuntu_ami" {
  type        = string
  description = "The Ubuntu 24.04 ami"
  default     = "ami-0e2c8caa4b6378d8c"
}

variable "worker_counts" {
  type        = number
  description = "Count of k8s cluster worker nodes"
  default     = 2
}