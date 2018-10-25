variable "servers" {
	description = "Number of master instances (always use odd numbers: 1, 3, 5)"
	default = 3
}

variable "security_group_id" {
  description = "Security group for master."
  default     = ""
}

variable "subnet_ids" {
  default     = []
  description = "A list of subnet ids (1 for each az)"
}

variable "azs" {
  default     = []
  description = "A list of azs"
}

variable "key_name" {
 default = ""
}

variable "instance_type" {
 default = "m3.medium"
}

variable "region" {
 default = ""
}

variable "iam_instance_profile_id" {
 default = ""
}

variable "role" {
 default = "default"
}

variable "extra_ebs" {
 default = 0 # 1 or 0
}

variable "extra_ebs_type" {
 default = "gp2"
}

variable "extra_ebs_size" {
 default = 0
}

variable "storage_type" {
 default = "instance-store"
}

variable "ami_id" {
}

variable "static_ip" {
  default = false
}
