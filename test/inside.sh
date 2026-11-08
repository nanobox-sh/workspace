#!/usr/bin/env bash
set -euo pipefail

failures=0
check() {
  local name="$1"; shift
  if out="$("$@" 2>&1)"; then
    printf 'ok   %-28s %s\n' "$name" "$(head -n1 <<<"$out")"
  else
    printf 'FAIL %-28s %s\n' "$name" "$(head -n3 <<<"$out" | tr '\n' ' ')"
    failures=$((failures + 1))
  fi
}
expect() {
  local name="$1" want="$2"; shift 2
  local got
  got="$("$@" 2>&1)" || true
  if [ "$got" = "$want" ]; then
    printf 'ok   %-28s %s\n' "$name" "$got"
  else
    printf 'FAIL %-28s want %q, got %q\n' "$name" "$want" "$got"
    failures=$((failures + 1))
  fi
}

expect "uid"                    1000        id -u
expect "login name"             dev         id -un
expect "home"                   /home/dev   sh -c 'echo "$HOME"'
expect "home is empty"          ""          ls -A /home/dev
check  "home is writable"       touch /home/dev/.probe
expect "workspace owner"        dev         stat -c %U /workspace
expect "login shell"            /bin/bash   sh -c 'getent passwd dev | cut -d: -f7'

check "claude"                  claude --version
check "codex"                   codex --version
check "pi"                      pi --version
check "node"                    node --version
check "npm"                     npm --version
check "python3"                 python3 --version
check "uv"                      uv --version
check "uvx"                     uvx --version
check "docker"                  docker --version
check "docker compose"          docker compose version
check "docker buildx"           docker buildx version
check "gh"                      gh --version
check "git"                     git --version
check "git-lfs"                 git lfs version
check "rg"                      rg --version
check "fd"                      fd --version
check "jq"                      jq --version
check "fzf"                     fzf --version
check "tmux"                    tmux -V
check "vim"                     vim --version
check "zsh"                     zsh --version
check "gcc"                     gcc --version
check "workspace-versions"      workspace-versions

check "sudo without password"   sudo -n true
expect "sudo is root"           0           sudo -n id -u
check "sudo apt-get"            sudo -n apt-get --version

expect "box env in bash login"  "from the box env" bash -lc 'echo "$NANOBOX_SMOKE"'
expect "box env in zsh login"   "from the box env" zsh -lc 'echo "$NANOBOX_SMOKE"'
expect "box env in sh login"    "from the box env" sh -lc 'echo "$NANOBOX_SMOKE"'
expect "autoupdater off"        1           sh -c 'echo "$DISABLE_AUTOUPDATER"'
expect "utf-8 locale"           en_US.UTF-8 sh -c 'echo "$LANG"'
expect "locale is generated"    "LC_CTYPE=\"en_US.UTF-8\"" sh -c 'locale 2>/dev/null | grep ^LC_CTYPE='

check "npm global dir is root's" sh -c 'test "$(stat -c %U /usr/local/lib/node_modules)" = root'
check "pi installed, not deprecated" sh -c 'test -d /usr/local/lib/node_modules/@earendil-works/pi-coding-agent && ! test -d /usr/local/lib/node_modules/@mariozechner'

echo
if [ "$failures" -gt 0 ]; then
  echo "$failures check(s) failed"
  exit 1
fi
echo "all checks passed"
