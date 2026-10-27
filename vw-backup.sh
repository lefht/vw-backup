#!/usr/bin/env bash
# Vaultwarden backup: consistent SQLite snapshot + keys/attachments -> restic (encrypted, off-Pi)
set -euo pipefail

VW_DATA="/home/wehelie/vaultwarden/data"   # path to your compose ./data folder
STAGE="/var/backups/vaultwarden-stage"

# restic repo + credentials (RESTIC_REPOSITORY, RESTIC_PASSWORD_FILE, B2/S3 keys)
source /root/.restic-env

rm -rf "$STAGE"
mkdir -p "$STAGE"

# Safe copy of the live database (don't just cp a running SQLite file)
sqlite3 "$VW_DATA/db.sqlite3" ".backup '$STAGE/db.sqlite3'"
sqlite3 "$STAGE/db.sqlite3" "PRAGMA integrity_check;" | grep -qx ok

# Keys and config (without rsa_key*, existing logins break on restore)
for f in rsa_key.pem rsa_key.pub.pem config.json; do
  [ -e "$VW_DATA/$f" ] && cp -a "$VW_DATA/$f" "$STAGE/"
done

# Attachments and Sends
for d in attachments sends; do
  [ -d "$VW_DATA/$d" ] && cp -a "$VW_DATA/$d" "$STAGE/"
done

restic backup "$STAGE" --tag vaultwarden
restic forget --tag vaultwarden --keep-daily 7 --keep-weekly 4 --keep-monthly 6 --prune

# status update
rm -rf "$STAGE"
echo "Vaultwarden backup OK: $(date -Is)"
