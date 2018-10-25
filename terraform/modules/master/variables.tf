variable "servers" {
	description = "Number of master instances (always use odd numbers: 1, 3, 5)"
	default = 3
}
variable "vpc_id" {
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

variable "iam_instance_profile_id" {
 default = ""
}

variable "instance_type" {
 default = "t2.micro"
}

variable "cluster_name" {
 default = ""
}

variable "region" {
 default = ""
}

variable "ami_id" {
 default = ""
}
