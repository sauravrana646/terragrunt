locals {
  aliases = { for k, v in toset(var.aliases) : k => { name = v } }
}