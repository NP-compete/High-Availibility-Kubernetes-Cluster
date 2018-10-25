output kubernetes_master_url {
  value = "${module.master.dns_name}"
}

output kubernetes_etcd_url {
  value = "${module.etcd.dns_name}"
}

output kubernetes_route_table_id {
  value = "${aws_route_table.kubernetes.id}"
}

output kubernetes_role {
  value = "${aws_iam_role.kubernetes.name}"
}

output aws_region {
  value = "${var.region}"
}

output s3_etcd_backup_bucket {
  value = "${module.etcd.backup_bucket}"
}

output "etcd_key_id" {
  value = ["${aws_iam_access_key.etcd_backuper.*.id}"]
}

output "etcd_key_secret" {
  value = ["${aws_iam_access_key.etcd_backuper.*.secret}"]
}

output "cluster_name" {
  value = "${var.cluster_name}"
}

output secrets_bucket {
  value = "${module.deployer.secrets_bucket}"
}

output "subnet_ids" {
	value = ["${aws_subnet.kubernetes.*.id}"]
}

output "security_group_id" {
	value = "${aws_security_group.kubernetes.id}"
}

output "iam_instance_profile_id" {
	value = "${aws_iam_instance_profile.kubernetes.id}"
}

output "key_name" {
	value = "${aws_key_pair.kubernetes.key_name}"
}

output "vpc_id" {
  value = "${aws_vpc.kubernetes.id}"
}

output "vpc_dns" {
  value = "${cidrhost(var.vpc_cidr, 2)}"
}

output "deployer_ip" {
  value = "${module.deployer.deployer_ip}"
}
