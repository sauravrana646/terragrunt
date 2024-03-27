locals {
  has_encrypted_password             = length(compact(aws_iam_user_login_profile.this[*].encrypted_password)) > 0
  has_encrypted_secret               = length(compact(aws_iam_access_key.this[*].encrypted_secret)) > 0
  has_encrypted_ses_smtp_password_v4 = length(compact(aws_iam_access_key.this[*].encrypted_ses_smtp_password_v4)) > 0
}