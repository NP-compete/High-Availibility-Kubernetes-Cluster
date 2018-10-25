variable "region" {}
variable "cluster_name" {}
variable "availability_zones" { type = "list" }
variable "existing_vpc_ids" { type = "list" }
variable "master_instance_type" { default="m4.large" }
variable "etcd_instance_type" { default="m4.large" }
variable "minion_instance_type" { default="m3.medium" }
variable "control_cidr" { default="" }
variable "public_key" {default=""}
variable "minion_count" { default=2 }
variable "subnet_mask_bytes" { default = 4 }
variable "vpc_cidr" { default = "172.21.0.0/16"}
variable "etcd_ami_id" {default=""}
variable "master_ami_id" {default=""}
variable "deployer_ami_id" {default=""}
variable "etcd_backup_keys" {default=1}
