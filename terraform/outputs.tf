output "instance_id" {
  value = aws_instance.app.id
}

output "public_ip" {
  value = aws_instance.app.public_ip
}

output "ssh" {
  value = "ssh -i ${var.ssh_private_key} ubuntu@${aws_instance.app.public_ip}"
}

output "url" {
  value = "http://${aws_instance.app.public_ip}"
}
