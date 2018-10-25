output instances {
  value = ["${aws_instance.worker.*.id}"]
}
