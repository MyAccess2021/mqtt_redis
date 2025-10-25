
# 🚀 MQTT + WebSocket + SSL + Redis (Fully Containerized Stack)

**Author:** MYACCESS PRIVATE LIMITED
**Version:** 2.1
**Last Updated:** 25 Oct 2025

---

## 🧭 Overview

This guide provides a **complete, production-ready MQTT + WebSocket + SSL (WSS)** setup using Docker, Certbot, and Redis.
It runs on **Ubuntu 24.04.3 LTS (Noble Numbat)** and is fully automated — including SSL certificate renewal and dynamic user provisioning.

---

## 🖥️ 0️⃣ **Server Configuration**

| Key                  | Value                             |
| -------------------- | --------------------------------- |
| **OS**               | Ubuntu 24.04.3 LTS (Noble Numbat) |
| **Codename**         | noble                             |
| **Architecture**     | amd64                             |
| **SSH Access**       | `ssh root@178.16.137.196`         |
| **Base Type**        | Debian-like                       |
| **Docker Engine**    | Docker CE 26.x                    |
| **Compose Plugin**   | v2.29.1 or later                  |
| **Hostname Example** | `srv-mqtt.myaccessio.com`         |

### **OS Info File (`/etc/os-release`)**

```
PRETTY_NAME="Ubuntu 24.04.3 LTS"
NAME="Ubuntu"
VERSION_ID="24.04"
VERSION="24.04.3 LTS (Noble Numbat)"
VERSION_CODENAME=noble
ID=ubuntu
ID_LIKE=debian
HOME_URL="https://www.ubuntu.com/"
SUPPORT_URL="https://help.ubuntu.com/"
BUG_REPORT_URL="https://bugs.launchpad.net/ubuntu/"
PRIVACY_POLICY_URL="https://www.ubuntu.com/legal/terms-and-policies/privacy-policy"
LOGO=ubuntu-logo
```

---

## ⚙️ 1️⃣ **Initial Server Setup**

### 1. Login as Root

```bash
ssh root@178.16.137.196
```

---

## 🐳 2️⃣ **Install Docker and Docker Compose**

Run the following commands step-by-step:

```bash
# Remove older versions (if any)
sudo apt-get remove docker docker-engine docker.io containerd runc

# Update and install dependencies
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg lsb-release

# Add Docker’s official GPG key
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# Add the Docker repository
echo \
"deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
| sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker Engine
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io

# Enable and start Docker
sudo systemctl enable docker
sudo systemctl start docker

# Add current user to Docker group
sudo usermod -aG docker $USER
newgrp docker

# Install Docker Compose (binary)
sudo curl -SL "https://github.com/docker/compose/releases/download/v2.29.1/docker-compose-linux-x86_64" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
sudo ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose

# Verify installation
docker --version
docker-compose --version
docker compose version

# (Optional) install Compose plugin via apt
sudo apt-get install -y docker-compose-plugin
```

---

## 📂 3️⃣ **Project Directory Setup**

```bash
cd ~
mkdir -p projects/mqtt
cd projects/mqtt
mkdir -p config/{certs,acls} data log redis scripts
chmod -R 777 config data log
```

---

## 🧱 4️⃣ **Folder Structure**

```
~/projects/mqtt/
├── config/
│   ├── acls
│   ├── certs/                   # Shared volume for certbot + mosquitto
│   ├── mosquitto.conf
│   ├── passwd
│   └── users.txt
├── data/
│   └── mosquitto.db
├── redis/
│   └── redis.conf
├── log/
│   └── mosquitto.log
├── scripts/
│   └── add-users.sh
└── docker-compose.yml
```

---

## 🧰 5️⃣ **docker-compose.yml**

```yaml
version: "3.9"

services:
  mosquitto:
    image: eclipse-mosquitto:2.0
    container_name: mqtt-broker
    restart: always
    depends_on:
      - certbot
    ports:
      - "1884:1883"
      - "8884:8883"
      - "9004:9001"
    volumes:
      - ./config/mosquitto.conf:/mosquitto/config/mosquitto.conf
      - ./config/passwd:/mosquitto/config/passwd
      - ./config/acls:/mosquitto/config/acls
      - ./config/certs:/etc/letsencrypt/live/yourdomain.com
      - ./data:/mosquitto/data
      - ./log:/mosquitto/log
      - ./scripts/add-users.sh:/usr/local/bin/add-users.sh
      - ./config/users.txt:/mosquitto/config/users.txt
    entrypoint: ["/bin/sh", "-c", "/usr/local/bin/add-users.sh && mosquitto -c /mosquitto/config/mosquitto.conf"]
    environment:
      - TZ=Asia/Kolkata

  certbot:
    image: certbot/certbot:latest
    container_name: certbot
    restart: unless-stopped
    command: certonly --standalone -d yourdomain.com --agree-tos --email admin@yourdomain.com --non-interactive --keep-until-expiring
    ports:
      - "80:80"
    volumes:
      - ./config/certs:/etc/letsencrypt/live/yourdomain.com

  redis:
    image: redis:7
    container_name: redis-cache
    restart: always
    command: ["redis-server", "/usr/local/etc/redis/redis.conf"]
    volumes:
      - ./redis/redis.conf:/usr/local/etc/redis/redis.conf
      - redis-data:/data
    ports:
      - "6379:6379"

volumes:
  redis-data:
```

> Replace `yourdomain.com` and `admin@yourdomain.com` with your actual domain and email.

---

## 🔐 6️⃣ **mosquitto.conf (SSL + WSS)**

```conf
persistence true
persistence_location /mosquitto/data/
persistence_file mosquitto.db

log_dest file /mosquitto/log/mosquitto.log
log_type all

allow_anonymous false
password_file /mosquitto/config/passwd
acl_file /mosquitto/config/acls

listener 1883

listener 8883
cafile /etc/letsencrypt/live/yourdomain.com/fullchain.pem
certfile /etc/letsencrypt/live/yourdomain.com/fullchain.pem
keyfile /etc/letsencrypt/live/yourdomain.com/privkey.pem
require_certificate false

listener 9001
protocol websockets
cafile /etc/letsencrypt/live/yourdomain.com/fullchain.pem
certfile /etc/letsencrypt/live/yourdomain.com/fullchain.pem
keyfile /etc/letsencrypt/live/yourdomain.com/privkey.pem
require_certificate false
```

---

## 👥 7️⃣ **users.txt**

```
admin:Admin@123
device1:Device@123
webapp:Web@123
```

---

## ⚡ 8️⃣ **add-users.sh**

```bash
#!/bin/sh
PASSWD_FILE="/mosquitto/config/passwd"
USERS_FILE="/mosquitto/config/users.txt"

echo "[INIT] Regenerating Mosquitto password file from users.txt..."
rm -f "$PASSWD_FILE"

while IFS=: read -r user pass; do
  [ -z "$user" ] && continue
  [ "${user#\#}" != "$user" ] && continue
  echo "  -> Adding user: $user"
  mosquitto_passwd -b "$PASSWD_FILE" "$user" "$pass"
done < "$USERS_FILE"

echo "[INIT] Password file updated."
```

Make it executable:

```bash
chmod +x scripts/add-users.sh
```

---

## 🧩 9️⃣ **Start Services**

```bash
docker compose up -d
docker compose logs -f certbot
```

Once certificates are issued:

```bash
ls -l config/certs/
docker restart mqtt-broker
```

---

## 🔁 🔄 **Auto Certificate Renewal (Cron Job)**

```bash
sudo crontab -e
```

Add this line:

```
0 3 * * * cd /root/projects/mqtt && docker run --rm -v $(pwd)/config/certs:/etc/letsencrypt/live/yourdomain.com certbot/certbot renew && docker restart mqtt-broker
```

---

## 🧠 🔍 **Verification**

### MQTT (SSL)

```bash
mosquitto_pub -h yourdomain.com -p 8884 --cafile config/certs/fullchain.pem \
  -u admin -P Admin@123 -t secure/topic -m "SSL works!"
```

### WebSocket (WSS)

```js
const client = new Paho.MQTT.Client("wss://yourdomain.com:9004/mqtt", "web-" + Math.random());
client.connect({
  userName: "admin",
  password: "Admin@123",
  useSSL: true,
  onSuccess: () => console.log("Connected via WSS")
});
```

---

## 📜 Logs and Monitoring

| Command                            | Description         |
| ---------------------------------- | ------------------- |
| `docker compose logs -f mosquitto` | Broker live logs    |
| `tail -f log/mosquitto.log`        | Raw file logs       |
| `docker compose logs -f certbot`   | SSL events          |
| `docker exec -it mqtt-broker sh`   | Access broker shell |

---

## 🧩 Troubleshooting

| Issue               | Cause                     | Solution                      |
| ------------------- | ------------------------- | ----------------------------- |
| SSL handshake error | Certbot not finished      | Wait & restart broker         |
| Permission denied   | Wrong volume permissions  | `chmod -R 777 config`         |
| Port 80 in use      | Web server running        | Stop Nginx/Apache temporarily |
| WSS reconnect loop  | Browser cache / wrong URL | Clear cache & verify `wss://` |
| Auth failed         | Incorrect credentials     | Update `users.txt` + restart  |

---

## ✅ Final Summary

| Component                        | Description            | Status |
| -------------------------------- | ---------------------- | ------ |
| **Ubuntu 24.04.3 LTS**           | Base OS                | ✅      |
| **Docker + Compose**             | Container runtime      | ✅      |
| **Mosquitto (MQTT + WSS + SSL)** | Secure messaging       | ✅      |
| **Certbot**                      | SSL issuance + renewal | ✅      |
| **Redis**                        | Cache / message sync   | ✅      |
| **Dynamic User Management**      | via `users.txt`        | ✅      |
| **Auto Renewal + Restart**       | via cron job           | ✅      |

---

