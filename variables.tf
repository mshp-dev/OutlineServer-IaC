variable "name_postfix" {
  type        = string
  description = "The postfix part of all objects name"
  default     = "outline_server"
}

variable "ssh_key_pair_name" {
  type        = string
  description = "The name of SSH key-pair"
  default     = "outline_ssh_key"
}

variable "aws_region" {
  type        = string
  description = "The AWS region"
  default     = "ca-central-1"
}

variable "ubuntu_ami" {
  type        = string
  description = "The Ubuntu 24.04 ami"
  default     = "ami-0bee12a638c7a8942"
}