# Single-node Vault with file storage. Everything in /vault/file is encrypted;
# after a restart Vault is sealed until it is unsealed (vault/bootstrap.sh does it).
ui            = true
disable_mlock = true

storage "file" {
  path = "/vault/file"
}

# Plain HTTP: the port is published only on 127.0.0.1 (see docker-compose.yml)
listener "tcp" {
  address     = "0.0.0.0:8200"
  tls_disable = true
}

api_addr = "http://127.0.0.1:8200"
