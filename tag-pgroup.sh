#!/bin/bash

# Script pour créer des tags pgroup sur tous les microservices et le frontend
# Usage: ./tag-pgroup.sh [--major|--minor|--patch] [--dry-run]

set -e

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
BASE_TAG="v2.0.0-pgroup"
DRY_RUN=false
VERSION_TYPE="patch" # par défaut: patch

# Repos à exclure (utilisent des tags simples vX.Y.Z sans suffixe)
EXCLUDED_REPOS=("ms-ai-kit" "router-cosmo")

# Fonction pour vérifier si un repo est exclu
is_excluded() {
  local repo_name="$1"
  for excluded in "${EXCLUDED_REPOS[@]}"; do
    if [[ "$repo_name" == "$excluded" ]]; then
      return 0
    fi
  done
  return 1
}

# Découverte dynamique des dépôts principaux (frontend-* + ms-*)
discover_repos() {
  local repos=()
  shopt -s nullglob
  for dir in frontend-* ms-*; do
    # Vérifier si c'est un repo git (dossier .git ou fichier .git pour submodules)
    if [ -d "$dir/.git" ] || [ -f "$dir/.git" ]; then
      repos+=("$dir")
    fi
  done
  shopt -u nullglob
  printf '%s\n' "${repos[@]}"
}

# Charger les repos et filtrer les entrées vides
REPOS=()
while IFS= read -r repo; do
  [[ -n "$repo" ]] && REPOS+=("$repo")
done < <(discover_repos)

# Dossier des sous-modules frontend (COMPONENTS-*)
FRONTEND_COMPONENTS_DIR="frontend-constellation/src/components"

# Fonction pour afficher l'aide
show_help() {
  echo "Usage: $0 [OPTIONS]"
  echo ""
  echo "Options:"
  echo "  --major       Incrémenter la version majeure (v2.0.0 -> v3.0.0)"
  echo "  --minor       Incrémenter la version mineure (v2.0.0 -> v2.1.0)"
  echo "  --patch       Incrémenter la version patch (v2.0.0 -> v2.0.1) [par défaut]"
  echo "  --dry-run     Afficher les tags qui seraient créés sans les créer"
  echo "  -h, --help    Afficher cette aide"
  echo ""
  echo "Exemples:"
  echo "  $0 --patch              # Crée v2.0.1-pgroup"
  echo "  $0 --minor              # Crée v2.1.0-pgroup"
  echo "  $0 --major              # Crée v3.0.0-pgroup"
  echo "  $0 --patch --dry-run    # Simule la création de v2.0.1-pgroup"
}

# Parser les arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --major)
      VERSION_TYPE="major"
      shift
      ;;
    --minor)
      VERSION_TYPE="minor"
      shift
      ;;
    --patch)
      VERSION_TYPE="patch"
      shift
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    -h|--help)
      show_help
      exit 0
      ;;
    *)
      echo -e "${RED}Option inconnue: $1${NC}"
      show_help
      exit 1
      ;;
  esac
done

# Fonction pour extraire et incrémenter la version
increment_version() {
  local version=$1
  local type=$2

  # Extraire les chiffres de la version (format: v2.0.1-pgroup)
  if [[ $version =~ v([0-9]+)\.([0-9]+)\.([0-9]+)-pgroup ]]; then
    local major="${BASH_REMATCH[1]}"
    local minor="${BASH_REMATCH[2]}"
    local patch="${BASH_REMATCH[3]}"

    case $type in
      major)
        major=$((major + 1))
        minor=0
        patch=0
        ;;
      minor)
        minor=$((minor + 1))
        patch=0
        ;;
      patch)
        patch=$((patch + 1))
        ;;
    esac

    echo "v${major}.${minor}.${patch}-pgroup"
  else
    echo ""
  fi
}

# Fonction pour obtenir le dernier tag pgroup d'un repo
get_latest_pgroup_tag() {
  local repo=$1
  local latest_tag=$(git tag | grep -E "^v[0-9]+\.[0-9]+\.[0-9]+-pgroup$" | sort -V | tail -1)
  echo "$latest_tag"
}

# Fonction pour créer un tag
create_tag() {
  local repo=$1
  local new_tag=$2
  local current_branch=$3

  if [ "$DRY_RUN" = true ]; then
    echo -e "${YELLOW}[DRY-RUN]${NC} git tag -a $new_tag -m \"Release $new_tag\" && git push origin $new_tag"
  else
    git tag -a "$new_tag" -m "Release $new_tag"
    git push origin "$new_tag"
    echo -e "${GREEN}✓${NC} Tag $new_tag créé et poussé"
  fi
}

# Affichage de l'en-tête
echo ""
echo "=========================================="
echo "  Création de tags pgroup"
echo "=========================================="
echo -e "Type de version: ${BLUE}$VERSION_TYPE${NC}"
echo -e "Mode: $([ "$DRY_RUN" = true ] && echo "${YELLOW}DRY-RUN${NC}" || echo "${GREEN}PRODUCTION${NC}")"
echo "=========================================="
echo ""

# Compteurs pour le résumé
SUCCESS_COUNT=0
SKIP_COUNT=0
ERROR_COUNT=0

process_repo() {
  local repo_path="$1"
  local display_name="${2:-$repo_path}"
  local base_name=$(basename "$repo_path")

  # Vérifier si le repo est exclu
  if is_excluded "$base_name"; then
    echo -e "${YELLOW}⚠${NC}  $display_name exclu (utilise des tags simples)"
    SKIP_COUNT=$((SKIP_COUNT + 1))
    return
  fi

  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BLUE}Traitement de: $display_name${NC}"
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

  if [ ! -d "$repo_path" ]; then
    echo -e "${RED}✗${NC} Le répertoire $repo_path n'existe pas"
    ERROR_COUNT=$((ERROR_COUNT + 1))
    echo ""
    return
  fi

  pushd "$repo_path" >/dev/null || return

  local current_branch
  current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")

  echo "→ Récupération des tags..."
  git fetch --tags --quiet || true

  local latest_tag
  latest_tag=$(get_latest_pgroup_tag "$repo_path")

  if [ -z "$latest_tag" ]; then
    echo -e "${YELLOW}⚠${NC}  Aucun tag pgroup trouvé, utilisation du tag de base: $BASE_TAG"
    latest_tag=$BASE_TAG
  else
    echo -e "→ Dernier tag pgroup trouvé: ${GREEN}$latest_tag${NC}"
  fi

  local new_tag
  new_tag=$(increment_version "$latest_tag" "$VERSION_TYPE")

  if [ -z "$new_tag" ]; then
    echo -e "${RED}✗${NC} Impossible de calculer le nouveau tag depuis $latest_tag"
    ERROR_COUNT=$((ERROR_COUNT + 1))
    popd >/dev/null
    echo ""
    return
  fi

  if git rev-parse "$new_tag" >/dev/null 2>&1; then
    echo -e "${YELLOW}⚠${NC}  Le tag $new_tag existe déjà, passage au suivant"
    SKIP_COUNT=$((SKIP_COUNT + 1))
    popd >/dev/null
    echo ""
    return
  fi

  echo -e "→ Nouveau tag à créer: ${GREEN}$new_tag${NC}"
  [ -n "$current_branch" ] && echo -e "→ Branche actuelle: ${BLUE}$current_branch${NC}"

  create_tag "$display_name" "$new_tag" "$current_branch"
  SUCCESS_COUNT=$((SUCCESS_COUNT + 1))

  popd >/dev/null
  echo ""
}

# Boucle sur les sous-modules frontend COMPONENTS-* (traités en premier)
if [ -d "$FRONTEND_COMPONENTS_DIR" ]; then
  echo ""
  echo "=========================================="
  echo "  Sous-modules frontend (components-*)"
  echo "=========================================="
  echo ""

  shopt -s nullglob
  for component in "$FRONTEND_COMPONENTS_DIR"/components-*; do
    process_repo "$component" "$(basename "$component")"
  done
  shopt -u nullglob
else
  echo -e "${YELLOW}⚠${NC}  Dossier $FRONTEND_COMPONENTS_DIR introuvable, composants non tagués."
fi

# Boucle sur les repos principaux (frontend + microservices)
for repo in "${REPOS[@]}"; do
  process_repo "$repo"
done

# Affichage du résumé
echo ""
echo "=========================================="
echo "  Résumé"
echo "=========================================="
echo -e "${GREEN}✓${NC} Tags créés avec succès: $SUCCESS_COUNT"
echo -e "${YELLOW}⚠${NC}  Tags existants (ignorés): $SKIP_COUNT"
echo -e "${RED}✗${NC} Erreurs: $ERROR_COUNT"
echo "=========================================="
echo ""

if [ "$DRY_RUN" = true ]; then
  echo -e "${YELLOW}Note: Mode DRY-RUN activé, aucun tag n'a été créé réellement.${NC}"
  echo -e "${YELLOW}Exécutez sans --dry-run pour créer les tags.${NC}"
  echo ""
fi

exit 0
