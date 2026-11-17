#!/usr/bin/env bash
# Выдать или отозвать доступ к приватным репозиториям серии AD Tools.
#
#   scripts/grant-access.sh <логин> [репозиторий ...]     пригласить (без списка — вся серия)
#   scripts/grant-access.sh --revoke <логин> [репозиторий ...]
#   scripts/grant-access.sh --list                          кто имеет доступ
#
# Нужен GitHub CLI (gh), вошедший под владельцем. На личном аккаунте GitHub приглашенный
# соавтор получает право записи (только чтения на личном аккаунте не бывает) — см. README.
set -euo pipefail

OWNER="${AD_TOOLS_OWNER:-Ismagulovne}"
ALL=(ad-phonebook ad-phonebook-lite ad-birthdays ad-orgchart ad-absence ad-rooms ad-helpdesk
     ad-inventory ad-onboarding ad-access ad-sspr ad-laps ad-certs ad-polls ad-audit
     ad-toolkit-lite ad-portal ad-tools-suite ad-tools-core ad-testlab)

if [ "${1:-}" = "--list" ]; then
  for r in "${ALL[@]}"; do
    users=$(gh api "repos/$OWNER/$r/collaborators?affiliation=direct" --jq '[.[].login]|join(", ")' 2>/dev/null || echo "?")
    pend=$(gh api "repos/$OWNER/$r/invitations" --jq '[.[].invitee.login]|join(", ")' 2>/dev/null || echo "")
    printf '%-18s %s%s\n' "$r" "$users" "${pend:+  (приглашены: $pend)}"
  done
  exit 0
fi

revoke=false
if [ "${1:-}" = "--revoke" ]; then revoke=true; shift; fi
login="${1:?Укажите логин GitHub}"; shift || true
if ! [[ "$login" =~ ^[A-Za-z0-9-]{1,39}$ ]]; then echo "Неверный логин: $login" >&2; exit 1; fi
repos=("$@"); [ ${#repos[@]} -eq 0 ] && repos=("${ALL[@]}")

for r in "${repos[@]}"; do
  if $revoke; then
    gh api -X DELETE "repos/$OWNER/$r/collaborators/$login" >/dev/null 2>&1 && echo "отозван: $r" || echo "нет доступа: $r"
    # незакрытое приглашение тоже отзываем
    for id in $(gh api "repos/$OWNER/$r/invitations" --jq ".[]|select(.invitee.login==\"$login\")|.id" 2>/dev/null); do
      gh api -X DELETE "repos/$OWNER/$r/invitations/$id" >/dev/null && echo "приглашение отозвано: $r"
    done
  else
    gh api -X PUT "repos/$OWNER/$r/collaborators/$login" -f permission=pull >/dev/null && echo "приглашен: $r"
  fi
done
