# Archive

Earlier architectures of this project. They are kept for history and are **not** used by the current deployment — the current setup is described in the [main README](../README.md).

| Stage | Architecture | Replaced by | Docs |
|---|---|---|---|
| 1 | nginx, php-fpm and systemd services directly on the EC2 host | Docker Compose (Stage 2) | [stage1-host](stage1-host/README.md) |
| 2 | Docker Compose, deployed by hand over SSH | Redis hit counter + Ansible deployment (Stage 3, current) | [stage2-docker](stage2-docker/README.md) |
