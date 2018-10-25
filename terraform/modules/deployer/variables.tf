variable "vpc_id" {
  default     = ""
}

variable "control_cidr" {
  default     = ""
  description = "CIDR of the instace used for running ansible"
}

variable "subnet_id" {
  default     = ""
  description = "A list of subnet ids (1 for each)"
}

variable "availability_zone" {
  default     = ""
}

variable "key_name" {
 default = ""
}

variable "instance_type" {
 default = "t2.micro"
}

variable "iam_instance_profile_id" {
 default = ""
}

variable "region" {
 default = ""
}

variable "cluster_name" {
 default = ""
}

variable "ami_id" {
 default = ""
}
