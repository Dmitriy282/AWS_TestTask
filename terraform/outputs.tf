output "instance_id" {
  value = aws_instance.app.id
}

output "public_ip" {
  value = aws_instance.app.public_ip
}

output "ssh" {
  description = "Works after ansible-playbook site.yml has written the key from Vault"
  value       = "ssh -i ${var.ssh_key_file} ubuntu@${aws_instance.app.public_ip}"
}

output "url" {
  value = "http://${aws_instance.app.public_ip}"
}

output "vault_secrets" {
  value = [for s in [vault_kv_secret_v2.ssh, vault_kv_secret_v2.ssh_public, vault_kv_secret_v2.app] : s.path]
}
