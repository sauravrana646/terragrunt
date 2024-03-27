resource "aws_iam_role" "this" {
  count = var.create_role ? 1 : 0

  name                 = var.role_name
  name_prefix          = var.role_name_prefix
  path                 = var.role_path
  max_session_duration = var.max_session_duration
  description          = var.role_description

  force_detach_policies = var.force_detach_policies
  permissions_boundary  = var.role_permissions_boundary_arn

  assume_role_policy = coalesce(
    var.custom_role_trust_policy,
    try(data.aws_iam_policy_document.assume_role[0].json, "")
  )

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "custom" {

  count = var.create_role ? coalesce(var.number_of_custom_role_policy_arns, length(var.custom_role_policy_arns)) : 0

  role       = aws_iam_role.this[0].name
  policy_arn = element(var.custom_role_policy_arns, count.index)
}

resource "aws_iam_role_policy_attachment" "admin" {
  count = var.create_role && var.attach_admin_policy ? 1 : 0

  role       = aws_iam_role.this[0].name
  policy_arn = var.admin_role_policy_arn
}

resource "aws_iam_role_policy_attachment" "poweruser" {
  count = var.create_role && var.attach_poweruser_policy ? 1 : 0

  role       = aws_iam_role.this[0].name
  policy_arn = var.poweruser_role_policy_arn
}

resource "aws_iam_role_policy_attachment" "readonly" {
  count = var.create_role && var.attach_readonly_policy ? 1 : 0

  role       = aws_iam_role.this[0].name
  policy_arn = var.readonly_role_policy_arn
}

resource "aws_iam_instance_profile" "this" {
  count = var.create_role && var.create_instance_profile ? 1 : 0
  name  = var.role_name
  path  = var.role_path
  role  = aws_iam_role.this[0].name

  tags = var.tags
}
