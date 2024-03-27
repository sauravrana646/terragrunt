resource "aws_kms_key" "this" {
  count = var.create ? 1 : 0

  description                        = var.description
  customer_master_key_spec           = var.customer_master_key_spec
  deletion_window_in_days            = var.deletion_window_in_days
  enable_key_rotation                = var.enable_key_rotation
  is_enabled                         = var.is_enabled
  key_usage                          = var.key_usage
  multi_region                       = var.multi_region
  bypass_policy_lockout_safety_check = var.bypass_policy_lockout_safety_check
  policy                             = coalesce(try(file(var.policy), ""), data.aws_iam_policy_document.this[0].json)

  tags = var.tags
}


################################################################################
# Alias
################################################################################


resource "aws_kms_alias" "this" {
  for_each = { for k, v in merge(local.aliases, var.computed_aliases) : k => v if var.create }

  name          = var.aliases_use_name_prefix ? null : "alias/${each.value.name}"
  name_prefix   = var.aliases_use_name_prefix ? "alias/${each.value.name}-" : null
  target_key_id = try(aws_kms_key.this[0].key_id)
}

################################################################################
# Grant
################################################################################

resource "aws_kms_grant" "this" {
  for_each = { for k, v in var.grants : k => v if var.create }

  name              = try(each.value.name, each.key)
  key_id            = try(aws_kms_key.this[0].key_id)
  grantee_principal = each.value.grantee_principal
  operations        = each.value.operations

  dynamic "constraints" {
    for_each = length(lookup(each.value, "constraints", {})) == 0 ? [] : [each.value.constraints]

    content {
      encryption_context_equals = try(constraints.value.encryption_context_equals, null)
      encryption_context_subset = try(constraints.value.encryption_context_subset, null)
    }
  }

  retiring_principal    = try(each.value.retiring_principal, null)
  grant_creation_tokens = try(each.value.grant_creation_tokens, null)
  retire_on_delete      = try(each.value.retire_on_delete, null)
}

