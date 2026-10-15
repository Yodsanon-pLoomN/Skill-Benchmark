#!/usr/bin/env bash
# Clones the three sample repositories from sample-repos/*.bundle into
# BENCH_DIR (default: $HOME/bench), with every task tag.
#
# BENCH_DIR must be OUTSIDE this repository: Claude Code loads CLAUDE.md and
# .claude/skills from every parent directory, so an agent run inside this
# repo would see the harness files and task notes (which contain answers).
set -euo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
BENCH_DIR="${BENCH_DIR:-$HOME/bench}"

case "$(cd "$(dirname "$BENCH_DIR")" 2>/dev/null && pwd)/$(basename "$BENCH_DIR")/" in
  "$HERE"/*) echo "BENCH_DIR must not be inside $HERE" >&2; exit 1 ;;
esac

mkdir -p "$BENCH_DIR"
for r in sample-project sample-project-reports-api sample-project-webapp; do
  if [ -d "$BENCH_DIR/$r/.git" ]; then
    echo "$r: already exists, fetching tags"
    git -C "$BENCH_DIR/$r" fetch -q --tags "$HERE/sample-repos/$r.bundle"
  else
    git clone -q "$HERE/sample-repos/$r.bundle" "$BENCH_DIR/$r"
    git -C "$BENCH_DIR/$r" fetch -q --tags "$HERE/sample-repos/$r.bundle"
  fi
  echo "$r: $(git -C "$BENCH_DIR/$r" tag | tr '\n' ' ')"
done

cat <<MSG

Done. Install dependencies before the first run:
  cd "$BENCH_DIR/sample-project"             && npm ci && cp -n .env.example .env 2>/dev/null; npx prisma db push
  cd "$BENCH_DIR/sample-project-webapp"      && npm ci
  cd "$BENCH_DIR/sample-project-reports-api" && dotnet restore
MSG
