#!/usr/bin/env bash
set -uo pipefail

PASS=0
FAIL=0

check() {
    local desc="$1"
    local expected="$2"
    local actual="$3"

    if [[ "$actual" == "$expected" ]]; then
        echo "  [OK]   $desc"
        ((PASS++))
    else
        echo "  [FAIL] $desc (ожидалось: '$expected', получено: '$actual')"
        ((FAIL++))
    fi
}

echo "Аудит конфигурации: $(hostname -f), $(date '+%Y-%m-%d %H:%M')"
echo "[1] Служба SSH"
check "Вход от имени root запрещён" "no" "$(sudo sshd -T | awk '/^permitrootlogin/{print $2}')"
check "Парольная аутентификация отключена" "no" "$(sudo sshd -T | awk '/^passwordauthentication/{print $2}')"
check "Порт SSH отличается от 22" "2222" "$(sudo sshd -T | awk '/^port/{print $2}')"
check "Максимум попыток аутентификации равен 3" "3" "$(sudo sshd -T | awk '/^maxauthtries/{print $2}')"

echo "[2] Межсетевой экран"
check "Межсетевой экран активен" "active" "$(sudo ufw status | awk '/^Status:/{print $2}')"
check "Политика входящего трафика — deny" "deny (incoming)" "$(sudo ufw status verbose | sed -n 's/^Default: \([^,]*\),.*/\1/p')"
echo "[3] Учётные записи"
awk -F: '$3>=1000 && $3<65534 {printf "    %s (uid=%s)\n",$1,$3}' /etc/passwd


echo "[4] Веб-сервер"
check "Nginx активен" "active" "$(systemctl is-active nginx 2>/dev/null || true)"
check "Конфигурация Nginx корректна" "valid" "$(sudo nginx -t >/dev/null 2>&1 && echo valid || echo invalid)"
check "Срок сертификата не менее 30 дней" "yes" "$(sudo openssl x509 -checkend 2592000 -noout -in /etc/ssl/certs/devops.crt >/dev/null 2>&1 && echo yes || echo no)"
check "Нет файлов сайта с записью для всех" "no" "$(find /var/www/devops-site -type f -perm -0002 -print -quit | grep -q . && echo yes || echo no)"
check "Права закрытого ключа равны 600" "600" "$(stat -c '%a' /etc/ssl/private/devops.key)"

echo "Пройдено: $PASS, не пройдено: $FAIL"
[[ "$FAIL" -eq 0 ]] && exit 0 || exit 1