#!/bin/bash
#
# diagnostica-git.sh — Fovea / By D.S.
#
# Controlla tutto ciò che Xcode Cloud pretende dal repository prima di
# accodare una build, e dice quale controllo è fallito.
#
#   ./diagnostica-git.sh                              solo diagnosi
#   ./diagnostica-git.sh --correggi URL_GITHUB        diagnosi e riparazione
#
# Va lanciato dalla cartella che contiene Fovea.xcodeproj.
#

set -u
CORREGGI=0
REMOTE_URL=""
[ "${1:-}" = "--correggi" ] && { CORREGGI=1; REMOTE_URL="${2:-}"; }

PROGETTO="Fovea.xcodeproj"
SCHEMA="$PROGETTO/xcshareddata/xcschemes/Fovea.xcscheme"
ok=0; ko=0

si()  { printf '  \033[32m✓\033[0m %s\n' "$1"; ok=$((ok+1)); }
no()  { printf '  \033[31m✗\033[0m %s\n' "$1"; ko=$((ko+1)); }
info(){ printf '    → %s\n' "$1"; }

echo
echo "══ Diagnostica repository per Xcode Cloud ══"
echo "Cartella: $(pwd)"
echo

# ── 1. la cartella giusta ────────────────────────────────────────────────
if [ -d "$PROGETTO" ]; then
  si "$PROGETTO presente in questa cartella"
else
  no "$PROGETTO non è qui — sei nella cartella sbagliata"
  info "Xcode Cloud vuole il repo con dentro il .xcodeproj. Spostati lì."
  exit 1
fi

# ── 2. repository git ────────────────────────────────────────────────────
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  si "è un repository Git"
else
  no "NON è un repository Git — questa è quasi certamente la causa"
  if [ $CORREGGI -eq 1 ]; then
    git init -b main >/dev/null && info "creato con 'git init -b main'"
  else
    info "rilancia con: ./diagnostica-git.sh --correggi https://github.com/tuo/repo.git"
    exit 1
  fi
fi

# ── 3. .gitignore sensato ────────────────────────────────────────────────
if [ -f .gitignore ]; then
  if grep -qE '^\s*\*?\.?xcodeproj|^\s*xcshareddata' .gitignore 2>/dev/null; then
    no ".gitignore esclude il progetto o gli schemi condivisi"
    info "Xcode Cloud non troverà niente da compilare. Rimuovi quelle righe."
  else
    si ".gitignore non esclude il progetto"
  fi
else
  if [ $CORREGGI -eq 1 ]; then
    cat > .gitignore <<'EOF'
# Xcode
build/
DerivedData/
*.xcuserstate
xcuserdata/
*.moved-aside
.DS_Store

# NON ignorare mai questi: a Xcode Cloud servono
!*.xcodeproj
!*.xcodeproj/project.pbxproj
!*.xcodeproj/xcshareddata/**
EOF
    si ".gitignore creato"
  else
    info ".gitignore assente (non è un errore, ma conviene)"
  fi
fi

# ── 4. almeno un commit ──────────────────────────────────────────────────
if git rev-parse HEAD >/dev/null 2>&1; then
  si "ha commit — ultimo: $(git log -1 --format='%h %s' 2>/dev/null)"
else
  no "NESSUN COMMIT sul repository"
  info "È esattamente ciò che produce 'Last Commit: Unknown'."
  if [ $CORREGGI -eq 1 ]; then
    git add -A >/dev/null
    git -c user.name="${GIT_AUTHOR_NAME:-Daniele Scruzzi}" \
        -c user.email="${GIT_AUTHOR_EMAIL:-dev@byds.local}" \
        commit -m "Fovea: primo commit" >/dev/null && si "primo commit creato"
  fi
fi

# ── 5. branch main ───────────────────────────────────────────────────────
BRANCH=$(git branch --show-current 2>/dev/null)
if [ "$BRANCH" = "main" ]; then
  si "sei sul branch main"
else
  no "branch attuale: '${BRANCH:-nessuno}', non 'main'"
  info "Il workflow punta a un branch che non esiste: la build resta accodata."
  [ $CORREGGI -eq 1 ] && git branch -M main && si "rinominato in main"
fi

# ── 6. remote origin ─────────────────────────────────────────────────────
ORIGIN=$(git remote get-url origin 2>/dev/null)
if [ -n "$ORIGIN" ]; then
  si "origin → $ORIGIN"
  case "$ORIGIN" in
    *github.com*) : ;;
    *) no "origin non punta a GitHub" ;;
  esac
else
  no "nessun remote 'origin'"
  if [ $CORREGGI -eq 1 ] && [ -n "$REMOTE_URL" ]; then
    git remote add origin "$REMOTE_URL" && si "origin aggiunto: $REMOTE_URL"
  else
    info "aggiungi con: git remote add origin https://github.com/tuo/repo.git"
  fi
fi

# ── 7. il progetto è tracciato ───────────────────────────────────────────
for f in "$PROGETTO/project.pbxproj" "$SCHEMA"; do
  if git ls-files --error-unmatch "$f" >/dev/null 2>&1; then
    si "tracciato: $f"
  else
    no "NON tracciato: $f"
    [ "$f" = "$SCHEMA" ] && info "Senza schema condiviso Xcode Cloud non sa cosa compilare."
    [ $CORREGGI -eq 1 ] && git add -f "$f" >/dev/null 2>&1 && info "aggiunto all'indice"
  fi
done

# ── 8. allineato con GitHub ──────────────────────────────────────────────
if [ -n "$ORIGIN" ] && git rev-parse HEAD >/dev/null 2>&1; then
  git fetch origin >/dev/null 2>&1
  if git rev-parse origin/main >/dev/null 2>&1; then
    AVANTI=$(git rev-list --count origin/main..HEAD 2>/dev/null || echo "?")
    if [ "$AVANTI" = "0" ]; then
      si "GitHub è allineato con il locale"
    else
      no "$AVANTI commit non ancora pushati"
      [ $CORREGGI -eq 1 ] && git push -u origin main && si "push eseguito"
    fi
  else
    no "il branch main non esiste su GitHub"
    info "Xcode Cloud sta guardando un branch vuoto."
    [ $CORREGGI -eq 1 ] && git push -u origin main && si "push eseguito"
  fi
fi

# ── esito ────────────────────────────────────────────────────────────────
echo
if [ $ko -eq 0 ]; then
  echo "══ $ok controlli superati, nessun problema lato repository ══"
  echo
  echo "Se le build restano accodate, il problema NON è il tuo repo. Controlla:"
  echo "  1. https://developer.apple.com/system-status/  (Xcode Cloud)"
  echo "  2. GitHub › Settings › Applications › Xcode Cloud › accesso a questo repo"
  echo "  3. App Store Connect › Xcode Cloud › il branch del workflow = main"
else
  echo "══ $ko problemi trovati, $ok controlli superati ══"
  [ $CORREGGI -eq 0 ] && echo "Rilancia con --correggi per sistemarli."
fi
echo
