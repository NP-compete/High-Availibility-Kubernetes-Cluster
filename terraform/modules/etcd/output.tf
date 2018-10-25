output dns_name {
  value = "${aws_alb.etcd.dns_name}"
}

output backup_bucket {
  value = "${aws_s3_bucket.backups.bucket}"
}
