module "ami" {
  source = "github.com/terraform-community-modules/tf_aws_ubuntu_ami"
  region = "${var.region}"
  distribution = "xenial"
  virttype = "hvm"
  storagetype = "${var.storage_type}"
}

resource "aws_ebs_volume" "ebs" {
  count = "${var.servers * var.extra_ebs}"
  availability_zone = "${element(var.azs, count.index / var.extra_ebs)}"
  type = "${var.extra_ebs_type}"
  size = "${var.extra_ebs_size}"
}

resource "aws_instance" "worker" {
  count = "${var.servers}"
  ami = "${var.ami_id != "" ? var.ami_id : module.ami.ami_id}"
  iam_instance_profile = "${var.iam_instance_profile_id}"
  instance_type = "${var.instance_type}"
  subnet_id = "${element(var.subnet_ids, count.index)}"
  associate_public_ip_address = true # Instances have public, dynamic IP
  source_dest_check = false # TODO Required??
  availability_zone = "${element(var.azs, count.index)}"
  vpc_security_group_ids = ["${var.security_group_id}"]
  key_name = "${var.key_name}"

  tags {
    ansible_managed = "yes",
    kubernetes_role = "worker"
    terraform_module = "minion"
    Name = "kube-minion"
    minion_role = "${var.role}"
  }
}

resource "aws_volume_attachment" "ebs_att" {
  count = "${var.servers * var.extra_ebs}"
  device_name = "/dev/sdf"
  volume_id = "${element(aws_ebs_volume.ebs.*.id, count.index)}"
  instance_id = "${element(aws_instance.worker.*.id, count.index / var.extra_ebs)}"
}

resource "aws_eip" "eip" {
  count = "${var.static_ip ? var.servers : 0}"
  vpc = true
  instance = "${element(aws_instance.worker.*.id, count.index)}"
}
