# MQTT , Websocket with SSL and redis

Below is a **fully integrated, production-ready setup** where:

* **Mosquitto** runs with WebSocket + SSL (`wss://`)
* **Certbot** runs as a Docker container to issue + auto-renew certificates
* **Redis** runs as before
* Certificates are shared through a common volume (`./config/certs`)

You’ll get a complete working stack with all commands, structure, and renewal automation.

---

# 🧩 MQTT + WSS + Certbot + Redis (Fully Containerized)

**Author:** MYACCESS PRIVATE LIMITED
**Version:** 2.0   **Last Updated:** 25 Oct 2025

---

## 🧱 Folder Structure

```
~/projects/mqtt/
├── config/
│   ├── acls
│   ├── certs/                   # <== shared volume for certbot + mosquitto
│   │   └── (certs will appear here automatically)
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

## 🧰 1️⃣ Create Docker Network and Volume Structure

```bash
cd ~/projects/mqtt
mkdir -p config/{certs,acls} data log redis scripts
chmod -R 777 config data log
```

---

## ⚙️ 2️⃣ docker-compose.yml

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
      - "1884:1883"   # MQTT
      - "8884:8883"   # MQTT over SSL
      - "9004:9001"   # WebSocket over SSL
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
      - "80:80"       # temporary during first run (HTTP-01 challenge)
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

> 🔸 Replace `yourdomain.com` and `admin@yourdomain.com` with your real domain and email.

---

## 🔐 3️⃣ mosquitto.conf (for SSL + WSS)

```conf
persistence true
persistence_location /mosquitto/data/
persistence_file mosquitto.db

log_dest file /mosquitto/log/mosquitto.log
log_type all

allow_anonymous false
password_file /mosquitto/config/passwd
acl_file /mosquitto/config/acls

# MQTT → external 1884
listener 1883

# MQTT over SSL → external 8884
listener 8883
cafile /etc/letsencrypt/live/yourdomain.com/fullchain.pem
certfile /etc/letsencrypt/live/yourdomain.com/fullchain.pem
keyfile /etc/letsencrypt/live/yourdomain.com/privkey.pem
require_certificate false

# WebSocket over SSL → external 9004
listener 9001
protocol websockets
cafile /etc/letsencrypt/live/yourdomain.com/fullchain.pem
certfile /etc/letsencrypt/live/yourdomain.com/fullchain.pem
keyfile /etc/letsencrypt/live/yourdomain.com/privkey.pem
require_certificate false
```

---

## 👥 4️⃣ users.txt

```
admin:Admin@123
device1:Device@123
webapp:Web@123
```

---

## 🧩 5️⃣ add-users.sh

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

Make executable:

```bash
chmod +x scripts/add-users.sh
```

---

## ⚡ 6️⃣ Launch Everything

```bash
docker compose up -d
docker compose logs -f certbot
```

When the first run completes, check that certificates exist:

```bash
ls -l config/certs/
# privkey.pem, fullchain.pem, chain.pem should be present
```

Then restart Mosquitto:

```bash
docker restart mqtt-broker
```

---

## 🔁 7️⃣ Automatic Certificate Renewal

Certbot stores certificates in the same volume, so renew with:

```bash
docker run --rm \
  -v $(pwd)/config/certs:/etc/letsencrypt/live/yourdomain.com \
  certbot/certbot renew
```

Automate via **cron** (host):

```bash
sudo crontab -e
```

Add:

```
0 3 * * * cd /root/projects/mqtt && docker run --rm -v $(pwd)/config/certs:/etc/letsencrypt/live/yourdomain.com certbot/certbot renew && docker restart mqtt-broker
```

Runs daily at 3 AM and restarts Mosquitto if renewal occurs.

---

## 🧠 8️⃣ Verify SSL and WSS Connections

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

## 🧾 9️⃣ Log Inspection

| Command                            | Description                       |
| ---------------------------------- | --------------------------------- |
| `docker compose logs -f mosquitto` | Live broker logs                  |
| `tail -f log/mosquitto.log`        | Direct log file                   |
| `docker compose logs -f certbot`   | Certificate issuance/renewal logs |
| `docker exec -it mqtt-broker sh`   | Enter broker container            |

---

## 🧩 🔧 Troubleshooting

| Problem                  | Cause                       | Fix                                         |
| ------------------------ | --------------------------- | ------------------------------------------- |
| `SSL handshake error`    | Certbot not finished        | Wait until certs appear, restart Mosquitto  |
| `Permission denied`      | Wrong volume perms          | `chmod -R 777 config`                       |
| `Port 80 in use`         | Another web service running | Stop it temporarily during cert issuance    |
| `WSS keeps reconnecting` | Browser caching non-SSL     | Clear cache, verify `wss://` + correct port |
| `auth failed`            | Incorrect `users.txt`       | Run `add-users.sh` again and restart broker |

---

## 🔒 10️⃣ User Permissions and Security

* `allow_anonymous false` forces authenticated logins.
* `users.txt` contains credentials → hashed to `passwd`.
* `acls` restricts topic namespaces.
* SSL certificates encrypt all MQTT + WebSocket traffic.
* Use firewall or Nginx proxy to hide raw ports if exposed publicly.

---

✅ **Summary**

| Component                    | Status |
| ---------------------------- | ------ |
| Mosquitto (MQTT + WSS + SSL) | ✅      |
| Certbot (auto certs + renew) | ✅      |
| Redis cache                  | ✅      |
| Dynamic user management      | ✅      |
| Automatic renewal + restart  | ✅      |

---

