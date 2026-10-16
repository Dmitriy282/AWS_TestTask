variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "name" {
  description = "Name tag of the instance, name of the security group and of the key pair"
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

variable "ssh_key_file" {
  description = "Where Ansible writes the private key from Vault on the machine that runs Ansible (written to the inventory)"
  type        = string
  default     = "~/.ssh/aws-testtask.pem"
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

# ---------- Vault ----------
variable "vault_addr" {
  type    = string
  default = "http://127.0.0.1:8200"
}

variable "vault_mount" {
  description = "KV v2 engine (created by vault/bootstrap.sh)"
  type        = string
  default     = "secret"
}

variable "vault_path" {
  description = "Path of the project's secrets in the engine: <path>/ssh, <path>/ssh-public, <path>/app"
  type        = string
  default     = "aws-testtask"
}

variable "secrets_version" {
  description = "Increase to generate a new SSH key and new passwords. The instance is replaced (new key, empty databases)"
  type        = number
  default     = 1
}
