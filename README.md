# Coding Agents

The nanobox workspace image for running coding agents. It is what a box runs
when its workspace is **Coding Agents** in the nanobox app.

```
ghcr.io/nanobox-sh/workspace:latest
```

Built for `linux/amd64` and `linux/arm64`, rebuilt weekly so the agents stay
current. Every tag that is a date (`2026.11.08`) or a commit (`sha-a1b2c3d`)
stays as it was built; `latest` follows `main`.

## What is in it

| Tool | Installed from |
| --- | --- |
| [Claude Code](https://code.claude.com) (`claude`) | Anthropic's signed apt repository, `latest` channel |
| [Codex](https://github.com/openai/codex) (`codex`) | npm, `@openai/codex` |
| [Pi](https://github.com/earendil-works/pi-mono) (`pi`) | npm, `@earendil-works/pi-coding-agent` |
| Node.js 24 LTS, npm | nodejs.org, checksum verified |
| Python 3, pip, venv, [uv](https://docs.astral.sh/uv/) | Ubuntu, astral-sh/uv image |
| Docker CLI, Compose, Buildx | download.docker.com |
| GitHub CLI (`gh`) | cli.github.com |
| git, git-lfs, ripgrep, fd, fzf, jq, tmux, vim, nano, zsh, build-essential, sqlite3, rsync, openssh-client | Ubuntu 24.04 |

`workspace-versions` prints the installed version of each. Every build writes
the same list to `/etc/workspace-versions` and to the workflow's job summary.

## How nanobox runs it

nanobox starts one container from this image per box and lands every SSH
session, exec and job inside it. The container runs as uid 1000 with host
networking; `/home/dev`, `/workspace` and the box's Docker socket are
bind-mounted from the VM. The image is built around that contract:

- **Nothing lives in the home directory.** The bind mount hides whatever the
  image put in `/home/dev`, so every tool is installed under `/usr`,
  `/usr/local` or `/opt`. Agent state (`~/.claude`, `~/.codex`, `~/.pi`,
  `~/.config/gh`) lands on the box's disk and survives container replacement.
- **The box user is `dev`, uid 1000**, with passwordless `sudo`. The box is a
  single trust domain and the VM is the boundary, so `sudo apt-get install`
  from a session is the intended way to add packages.
- **The login shell is bash.** `zsh` is installed; a login zsh reads
  `/etc/profile.d` as well, so the box environment that nanobox writes to
  `/etc/nanobox/env` reaches either shell.
- **Docker works through the mounted socket.** nanobox puts `dev` in the
  group that owns it; this image supplies the client.
- **Claude Code's auto-updater is off** (`DISABLE_AUTOUPDATER=1`): a
  system-wide install cannot update itself from a session. New versions
  arrive with the next image build.

## Using it outside nanobox

```bash
docker run --rm -it \
  -v "$PWD:/workspace" -w /workspace \
  -v /var/run/docker.sock:/var/run/docker.sock \
  ghcr.io/nanobox-sh/workspace:latest
```

The home directory is then the image's own and is discarded with the
container; mount a volume at `/home/dev` to keep agent logins between runs.

## Building

```bash
make build      # ghcr.io/nanobox-sh/workspace:dev for the host architecture
make test       # build, then test/smoke.sh against it
make versions   # print the installed tool versions
```

`test/smoke.sh` runs the image as nanobox does: uid 1000, an empty home, and
the platform's env file and profile script mounted in. It checks every tool
above, `sudo`, and that the box environment reaches bash, zsh and sh login
shells.

Build arguments pin what the Dockerfile fetches: `NODE_VERSION`,
`CLAUDE_CODE_CHANNEL` (`latest` or `stable`), `CODEX_VERSION` and
`PI_VERSION` (npm versions or `latest`), `UV_VERSION`, `UBUNTU_VERSION`.

## Releases

Every push to `main`, and the weekly schedule, publishes `latest`, a date tag
and a short commit tag. A git tag `vX.Y.Z` additionally publishes `X.Y.Z` and
`X.Y`. Pull requests build and run the smoke test on both architectures
without publishing.

## License

MIT. The tools inside the image keep their own licenses.
