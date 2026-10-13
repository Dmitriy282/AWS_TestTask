# AWS_TestTask

# AWS DevOps Lab — Stage 1: EC2 + Nginx (PHP, Python, Node.js)

Hands-on DevOps practice following my mentor's roadmap. In this stage I launched an EC2 instance on AWS, installed nginx and deployed three web applications — PHP, Python (Flask) and Node.js (Express). Each application is served by nginx on its own port.

## Task

The assignment from my mentor:

1. Create an SSH key pair, launch a `t3.micro` instance, create a security group for HTTP/HTTPS (80/443), install nginx.
2. Create SSH keys locally and add the public key to the server — a dedicated key for GitHub/GitLab.
3. Create three sites in nginx on ports **80**, **8000** and **8080**. Use three repositories — Python, Node.js and PHP — and make them work.
4. Document everything in a README with screenshots. Learn to present the work.

## Status

- [x] EC2 `t3.micro` instance with a key pair
- [x] Security group (22, 80, 443, 8000, 8080)
- [x] nginx installed and running
- [x] Site 1 — PHP on port 80
- [x] Site 2 — Python (Flask + gunicorn) on port 8000
- [x] Site 3 — Node.js (Express) on port 8080
- [x] Python and Node.js apps run as systemd services (start on boot, restart on failure)
- [ ] Dedicated SSH key for GitHub/GitLab CI → server
- [ ] Application code moved to Git repositories
- [ ] HTTPS (TLS certificate) on port 443

## Architecture

```mermaid
flowchart LR
    user(["Browser"])
    sg{{"Security group<br/>80 · 8000 · 8080"}}

    subgraph ec2["EC2 t3.micro · Ubuntu 24.04"]
        nginx["nginx"]
        php["php-fpm 8.3<br/>/var/www/html"]
        flask["gunicorn + Flask<br/>127.0.0.1:5000"]
        node["Node.js + Express<br/>127.0.0.1:3000"]
    end

    user --> sg --> nginx
    nginx -->|":80 → unix socket"| php
    nginx -->|":8000 → reverse proxy"| flask
    nginx -->|":8080 → reverse proxy"| node
```

| Site | Public port | Backend | Code location |
|---|---|---|---|
| 1 — PHP | 80 | php-fpm 8.3 (unix socket `/run/php/php8.3-fpm.sock`) | `/var/www/html` |
| 2 — Python | 8000 | gunicorn + Flask on `127.0.0.1:5000` | `/home/flask` |
| 3 — Node.js | 8080 | Express on `127.0.0.1:3000` | `/home/site2` |

nginx is the only process that listens on public ports. The application servers listen on `127.0.0.1` only, so they cannot be reached from the internet directly — all traffic goes through nginx.

## Environment

| Component | Version |
|---|---|
| Cloud | AWS EC2, region `us-east-1` (N. Virginia) |
| Instance type | `t3.micro` |
| OS | Ubuntu 24.04.4 LTS (kernel 6.17, AWS) |
| nginx | 1.24.0 |
| PHP | 8.3.6 (php-fpm) |
| Python | 3.12.3 (Flask, gunicorn) |
| Node.js | 24.21.0 (Express) |

## Step by step

### 1. Launch the EC2 instance

- **AMI:** Ubuntu Server 24.04 LTS
- **Instance type:** `t3.micro`
- **Key pair:** a new key pair; the private key was downloaded as a `.pem` file
- **Security group:** see the next step

![EC2 instance details](docs/img/01-ec2-instance.png)

### 2. Security group

Inbound rules:

| Port | Protocol | Source | Purpose |
|---|---|---|---|
| 22 | TCP | 0.0.0.0/0 | SSH (should be limited to my IP — see [Security notes](#security-notes)) |
| 80 | TCP | 0.0.0.0/0 | Site 1 — PHP |
| 443 | TCP | 0.0.0.0/0 | HTTPS (reserved, TLS is not configured yet) |
| 8000 | TCP | 0.0.0.0/0 | Site 2 — Flask |
| 8080 | TCP | 0.0.0.0/0 | Site 3 — Node.js |

Outbound: all traffic allowed (default).

![Security group inbound rules](docs/img/02-security-group.png)

### 3. Connect to the server

```bash
chmod 400 <key>.pem                      # Linux / WSL: private key must not be readable by others
ssh -i <key>.pem ubuntu@<EC2_PUBLIC_IP>
sudo -i
```

On Windows (PowerShell) the same is done with `icacls`:

```powershell
icacls .\<key>.pem /inheritance:r
icacls .\<key>.pem /grant:r "$($env:USERNAME):(R)"
```

### 4. Install nginx

```bash
apt update
apt install nginx
systemctl status nginx
curl localhost
```

![nginx status](docs/img/03-nginx-status.png)

### 5. Site 1 — PHP (port 80)

```bash
apt install php-fpm
systemctl status php8.3-fpm
```

The page is `/var/www/html/index.php`. nginx passes `.php` requests to php-fpm through a unix socket (see the nginx config in step 8).

### 6. Site 2 — Python / Flask (port 8000)

Create a virtual environment and install Flask and gunicorn:

```bash
apt install python3-venv
mkdir /home/flask && cd /home/flask
python3 -m venv venv
source venv/bin/activate
pip install flask gunicorn
```

Files in `/home/flask`:

- `app.py` — the Flask application (object `app`)
- `wsgi.py` — entry point for gunicorn, imports `app` from `app.py`

Test run:

```bash
gunicorn --bind 127.0.0.1:5000 wsgi:app
```

systemd unit `/etc/systemd/system/myflaskapp.service`:

```ini
[Unit]
Description=Gunicorn instance to serve myflaskapp
After=network.target

[Service]
WorkingDirectory=/home/flask
Environment="PATH=/home/flask/venv/bin"
ExecStart=/home/flask/venv/bin/gunicorn --workers 3 --bind 127.0.0.1:5000 wsgi:app
Restart=always

[Install]
WantedBy=multi-user.target
```

```bash
systemctl daemon-reload
systemctl enable --now myflaskapp
systemctl status myflaskapp
```

### 7. Site 3 — Node.js / Express (port 8080)

Node.js was installed from the official binary archive:

```bash
cd /home
wget https://nodejs.org/dist/v24.21.0/node-v24.21.0-linux-x64.tar.xz
tar xf node-v24.21.0-linux-x64.tar.xz
mv node-v24.21.0-linux-x64 /home/nodejs

echo 'export PATH="/home/nodejs/bin:$PATH"' >> ~/.profile
source ~/.profile
node -v
```

The application:

```bash
mkdir /home/site2 && cd /home/site2
npm init -y
npm install express
# server.js — Express app listening on port 3000
node server.js   # quick test
```

systemd unit `/etc/systemd/system/site2.service`:

```ini
[Unit]
Description=Node.js Express app (site 3)
After=network.target

[Service]
WorkingDirectory=/home/site2
Environment=NODE_ENV=production
Environment=PORT=3000
ExecStart=/home/nodejs/bin/node /home/site2/server.js
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
```

> systemd does not read `~/.profile`, so `ExecStart` uses the full path to `node`.

```bash
systemctl daemon-reload
systemctl enable --now site2
systemctl status site2
```

![Application services status](docs/img/04-services-status.png)

### 8. nginx configuration

`/etc/nginx/sites-available/default` (symlinked to `/etc/nginx/sites-enabled/`):

```nginx
# Site 1: PHP on port 80
server {
    listen 80 default_server;
    server_name _;
    root /var/www/html;
    index index.php index.html;

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php8.3-fpm.sock;
    }
}

# Site 2: Flask (gunicorn) on port 8000
server {
    listen 8000;
    server_name _;

    location / {
        include proxy_params;
        proxy_pass http://127.0.0.1:5000;
    }
}

# Site 3: Node.js (Express) on port 8080
server {
    listen 8080;
    server_name _;

    location / {
        include proxy_params;
        proxy_pass http://127.0.0.1:3000;
    }
}
```

Key points:

- **One `server` block per site** — each site has its own port (`listen`).
- **`server_name _`** — accept any host name, including requests to the bare IP.
- **`snippets/fastcgi-php.conf`** — standard Ubuntu snippet: sets `SCRIPT_FILENAME` and returns 404 if the PHP file does not exist.
- **`proxy_pass`** — nginx works as a reverse proxy for the Python and Node.js apps.
- **`proxy_params`** — passes the original `Host`, client IP (`X-Real-IP`, `X-Forwarded-For`) and protocol to the application.

### 9. Apply and verify

```bash
systemctl daemon-reload
systemctl restart myflaskapp          # first: gunicorn releases port 8000
nginx -t && systemctl restart nginx   # then: nginx takes 8000
ss -tlnp | grep -E ':(80|8000|8080|5000|3000)\b'
```

Result (simplified):

```
LISTEN  0.0.0.0:80       nginx
LISTEN  0.0.0.0:8000     nginx
LISTEN  0.0.0.0:8080     nginx
LISTEN  127.0.0.1:5000   gunicorn
LISTEN  127.0.0.1:3000   node
```

Local check from the server:

```bash
curl -s localhost:80   | head -5
curl -s localhost:8000 | head -5
curl -s localhost:8080 | head -5
```

![Listening ports](docs/img/05-listening-ports.png)

Check from the browser — `http://<EC2_PUBLIC_IP>`, `:8000` and `:8080`:

![Site 1 — PHP on port 80](docs/img/06-site-php-80.png)

![Site 2 — Flask on port 8000](docs/img/07-site-flask-8000.png)

![Site 3 — Node.js on port 8080](docs/img/08-site-node-8080.png)

### 10. SSH key for GitHub / GitLab (in progress)

A separate key pair that CI (GitHub Actions / GitLab CI) will use to connect to the server and deploy. It is **not** the AWS key pair.

On the local machine (no passphrase — CI cannot type it):

```powershell
ssh-keygen -t ed25519 -f $HOME\.ssh\ec2-cicd -C "github-gitlab-deploy"
type $HOME\.ssh\ec2-cicd.pub
```

On the server — add the public key for the `ubuntu` user:

```bash
echo "<contents of ec2-cicd.pub>" >> /home/ubuntu/.ssh/authorized_keys
```

Check the login with the new key:

```powershell
ssh -i $HOME\.ssh\ec2-cicd ubuntu@<EC2_PUBLIC_IP>
```

The private key is never committed. In the CI/CD stage it will be stored as a CI secret.

## How the setup evolved: v1 → v2

The first version used **path-based routing** on port 80:

```
http://<IP>/site1/  →  PHP
http://<IP>/site2/  →  Flask    (127.0.0.1:8000)
http://<IP>/site3/  →  Node.js  (127.0.0.1:3000)
```

It worked, but:

- it did not match the task — the sites must be on ports 80, 8000 and 8080;
- an app behind a path prefix generates wrong links and redirects (for example `/login` instead of `/site2/login`) unless each app is configured to know its prefix;
- PHP with `alias` needed a manually built `SCRIPT_FILENAME`.

The second version (current) is **port-based**: one `server` block per site. The config is simpler and there are no prefix problems. The v1 config is kept on the server as a backup (`/root/nginx-v1-path-based.conf`).

## Problems and solutions

**1. PHP script not found with `alias` (v1)**
- *Cause:* with `alias`, the default `$document_root$fastcgi_script_name` builds a wrong path to the file (`/var/www/html//site1/index.php`).
- *Fix:* `fastcgi_param SCRIPT_FILENAME $request_filename;`. In v2 the problem is gone: `root` + the standard snippet.

**2. `/site1` without a trailing slash did not open (v1)**
- *Cause:* `location /site1/` does not match the URL `/site1`.
- *Fix:* exact-match redirect `location = /site1 { return 301 /site1/; }`.

**3. gunicorn could not import the app**
- *Cause:* `wsgi.py` imports `app`, but the Flask file was named `touch.py`. The import refers to a local file, not to a pip package, so installing packages does not help.
- *Fix:* renamed the file to `app.py`.

**4. `node` / `npm` not found after unpacking the archive**
- *Cause:* `/home/nodejs/bin` was not in `PATH`. Running `~/.profile` as a command does not change the current shell.
- *Fix:* added `export PATH=...` to `~/.profile` and loaded it with `source ~/.profile`. In systemd — full path to `node`.

**5. Port 8000 conflict when moving to v2**
- *Cause:* gunicorn was listening on `127.0.0.1:8000`, but nginx needs `0.0.0.0:8000` for site 2.
- *Fix:* moved gunicorn to `127.0.0.1:5000` and restarted it before nginx.

## Security notes

- Only nginx is exposed to the internet; application servers bind to `127.0.0.1`.
- SSH (22) is open to `0.0.0.0/0` — it should be limited to my IP address.
- Port 443 is open, but TLS is not configured yet.
- The application services run as `root` — they should run as an unprivileged user (`User=` in the systemd units).
- Private keys (`.pem`, CI key) are never committed. The public IP and AWS account ID are hidden in this README and in the screenshots.

## Next steps

Roadmap:

1. Move the three applications to Git repositories and deploy from them
2. CI/CD pipeline (GitHub Actions / GitLab CI) using the dedicated SSH key
3. Containerization (Docker)
4. Load balancer
5. Infrastructure as Code with Terraform
6. Databases: PostgreSQL and MySQL

Small fixes:

- run the app services as a non-root user;
- rename `site2.service` and `/home/site2` to match the site numbering (it is site 3).
