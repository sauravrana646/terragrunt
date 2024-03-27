locals {
  this_sg_id = var.create_sg ? concat(aws_security_group.this.*.id, [""])[0] : var.security_group_id
}
