module "ami" {
  source = "github.com/terraform-community-modules/tf_aws_ubuntu_ami"
  region = "${var.region}"
  distribution = "xenial"
  virttype = "hvm"
  storagetype = "ebs-ssd"
}


resource "aws_instance" "controller" {

    count = "${var.servers}"
    ami = "${var.ami_id != "" ? var.ami_id : module.ami.ami_id}"

    instance_type = "${var.instance_type}"

    iam_instance_profile = "${var.iam_instance_profile_id}"

    subnet_id = "${element(var.subnet_ids, count.index)}"
    associate_public_ip_address = true # Instances have public, dynamic IP
    source_dest_check = false # TODO Required??

    availability_zone = "${element(var.azs, count.index)}"
    vpc_security_group_ids = ["${var.security_group_id}"]
    key_name = "${var.key_name}"

    tags {
      ansible_managed = "yes",
      kubernetes_role = "controller"
      terraform_module = "master"
      Name = "kube-master"
    }
}




############
# KUBE CONTROLLER ALB
############
resource "aws_alb" "controller" {
  name            = "tf-master-${var.cluster_name}"
  internal        = true
  security_groups = ["${var.security_group_id}"]
  subnets         = ["${var.subnet_ids}"]
  tags {
    terraform_module = "master"
  }
}

## 6443

resource "aws_alb_target_group" "controller" {
  name     = "tf-master-6443-${var.cluster_name}"
  port     = 6443
  protocol = "HTTP"
  vpc_id   = "${var.vpc_id}"
  health_check {
    path   = "/healthz"
    port   = 8080
  }
}


resource "aws_alb_listener" "controller" {
  load_balancer_arn = "${aws_alb.controller.id}"
  port              = "6443"
  protocol          = "HTTP"

  default_action {
    target_group_arn = "${aws_alb_target_group.controller.id}"
    type             = "forward"
  }
}

resource "aws_alb_target_group_attachment" "controller" {
  count = "${var.servers}"
  target_group_arn = "${aws_alb_target_group.controller.arn}"
  target_id = "${element(aws_instance.controller.*.id, count.index)}"
  port = 6443
}

## 8080

resource "aws_alb_target_group" "controller_8080" {
  name     = "tf-master-8080-${var.cluster_name}"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = "${var.vpc_id}"
  health_check {
    path   = "/healthz"
    port   = 8080
  }
}

resource "aws_alb_listener" "controller_8080" {
  load_balancer_arn = "${aws_alb.controller.id}"
  port              = "8080"
  protocol          = "HTTP"

  default_action {
    target_group_arn = "${aws_alb_target_group.controller_8080.id}"
    type             = "forward"
  }
}


resource "aws_alb_target_group_attachment" "controller_8080" {
  count = "${var.servers}"
  target_group_arn = "${aws_alb_target_group.controller_8080.arn}"
  target_id = "${element(aws_instance.controller.*.id, count.index)}"
  port = 8080
}
