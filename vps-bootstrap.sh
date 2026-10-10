bash <<'ANGLERFIN_SETUP'
set -euo pipefail
[ "$(id -u)" = 0 ] || { echo 'STOP: log in as root'; exit 1; }
getent passwd gha-runner >/dev/null
getent group quiverdata >/dev/null
command -v sshd >/dev/null
sshd -t
stamp=$(date +%Y%m%d-%H%M%S)
install -d -m 700 -o root -g root /root/.ssh
[ ! -L /root/.ssh/authorized_keys ] || { echo 'STOP: authorized_keys is a symlink'; exit 1; }
if [ -f /root/.ssh/authorized_keys ]; then
  cp -a /root/.ssh/authorized_keys "/root/.ssh/authorized_keys.before-anglerfin-$stamp"
fi
touch /root/.ssh/authorized_keys
printf '\n' >> /root/.ssh/authorized_keys
while IFS= read -r key; do
  grep -qxF "$key" /root/.ssh/authorized_keys || printf '%s\n' "$key" >> /root/.ssh/authorized_keys
done <<'KEYS'
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFvS9aW96h6ba2SWt5wJyI007Uv1+3kR7g3AECWFGdQp anglerfin-primary-20261009
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHLaS5VSj0fD9wuZcxBhxwTpeoyZamFUX3jLBERRxEbv anglerfin-spare-20261009
KEYS
chown root:root /root/.ssh/authorized_keys
chmod 600 /root/.ssh/authorized_keys
usermod -aG quiverdata gha-runner
mapfile -t units < <(systemctl list-units --all --type=service --no-legend --plain 'actions.runner.*.service' | awk '{print $1}')
if [ "${#units[@]}" -gt 0 ]; then
  systemctl restart "${units[@]}"
else
  echo 'WARNING: no actions.runner service found; runner restart still needed'
fi
printf '\nHOST: '; hostname
id gha-runner
sshd -T | grep -E '^(permitrootlogin|pubkeyauthentication|passwordauthentication|authorizedkeysfile) '
echo 'DONE: keys installed; SSH settings and password login unchanged. Keep this console open for key-login verification.'
ANGLERFIN_SETUP
