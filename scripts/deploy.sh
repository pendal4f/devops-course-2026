#!/usr/bin/env bash
set -euo pipefail

if [[ $# -gt 1 ]]; then
    echo "Использование: $0 [--dry-run]" >&2
    exit 2
fi

mode="${1:-deploy}"
if [[ "$mode" != "deploy" && "$mode" != "--dry-run" ]]; then
    echo "Использование: $0 [--dry-run]" >&2
    exit 2
fi

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(git -C "$script_dir" rev-parse --show-toplevel)"
cd "$repo_root"

if [[ ! -f site/index.html ]]; then
    echo "Ошибка: отсутствует site/index.html" >&2
    exit 1
fi

git ls-files --error-unmatch site/index.html >/dev/null 2>&1 || {
    echo "Ошибка: site/index.html не отслеживается Git" >&2
    exit 1
}

if [[ -n "$(git status --porcelain --untracked-files=all)" ]]; then
    echo "Ошибка: сначала закоммить изменения в репозитории" >&2
    exit 1
fi

commit_hash="$(git rev-parse --short HEAD)"
rsync_args=(-avz --delete --chmod=D755,F644 -e 'ssh -o BatchMode=yes')

if [[ "$mode" == "--dry-run" ]]; then
    rsync_args+=(--dry-run)
fi

rsync "${rsync_args[@]}" "$repo_root/site/" devops:/var/www/devops-site/

if [[ "$mode" == "--dry-run" ]]; then
    echo "DRY RUN завершён для коммита $commit_hash"
    exit 0
fi

curl --fail --silent --show-error \
    --cacert "$HOME/devops.crt" \
    --resolve devops.local:443:192.168.56.102 \
    https://devops.local/ >/dev/null

mkdir -p "$HOME/.local/state"
printf '%s %s\n' "$(date -Is)" "$commit_hash" >> "$HOME/.local/state/devops-deploy.log"
echo "Развёртывание успешно. Коммит: $commit_hash"
