variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "name" {
  description = "Name tag of the instance and name of the security group"
  type        = string
  default     = "aws-testtask"
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "volume_gb" {
  description = "Root volume size. The images take ~8 GB; the default 8 GB volume is not enough"
  type        = number
  default     = 20
}

variable "key_name" {
  description = "Name of an existing EC2 key pair in the region"
  type        = string
}

variable "ssh_private_key" {
  description = "Path to the private key of key_name on the machine that runs Ansible (written to the inventory)"
  type        = string
}

variable "ssh_cidr" {
  description = "Who may connect to SSH. Default: the public IP of the machine that runs Terraform"
  type        = string
  default     = null
}

variable "web_ports" {
  description = "Ports open to everyone"
  type        = list(number)
  default     = [80, 443, 8000, 8080]
}
