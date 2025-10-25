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
