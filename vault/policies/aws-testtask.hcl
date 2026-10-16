# Policy of the token used by Terraform (writes the secrets) and Ansible (reads them).
# Only the project's own path in the KV v2 engine `secret/`.

path "secret/data/aws-testtask/*" {
  capabilities = ["create", "read", "update", "delete"]
}

path "secret/metadata/aws-testtask/*" {
  capabilities = ["read", "list", "delete"]
}

# The Terraform provider does not use this token directly: it creates a short-lived child token
path "auth/token/create" {
  capabilities = ["update"]
}
