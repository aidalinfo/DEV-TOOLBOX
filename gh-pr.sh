#!/bin/bash

##Function
# Fonction pour demander confirmation
confirm() {
    # Afficher le message de demande de confirmation
    echo "$1"
    # Attendre la réponse de l'utilisateur
    read -r -p "Êtes-vous sûr ? (y/n) " -u 3 response 3</dev/tty
    if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        return 0
    else
        return 1
    fi
}


# Fonction pour vérifier l'existence de la branche et créer/merger une PR
check_and_multiple_pr() {
    local dir=$1
    local source_branch=$2
    local dest_branch=$3
    echo "Vérification dans $dir pour la branche $source_branch..."
    # Vérifie si la branch existe par repertoire
    if git -C "$dir" ls-remote --heads origin "$source_branch" | grep -q "$source_branch"; then
        echo "La branche '$source_branch' existe dans $dir."
        git -C "$dir" checkout "$source_branch"
        git -C "$dir" pull origin "$source_branch"
        check_and_pr_and_merge "$source_branch" "$dest_branch" "$dir" $4 $5
    else
        echo "La branche '$source_branch' n'existe pas dans $dir."
        echo "PWD: $(pwd)"
    fi
}

# Fonction pour créer et fusionner une PR
check_and_pr_and_merge() {
    local source_branch=$1
    local dest_branch=$2
    local dir=$3
    local ROOT_DIR=$(pwd)
    echo "Traitement du répertoire : $dir"
    cd "$dir" || return

    # Création de la PR
    PR_CREATE_OUTPUT=$(gh pr create --base "$dest_branch" --head "$source_branch" --fill)
    if [[ $? -ne 0 ]]; then
        echo "La création de la Pull Request a échoué dans $dir."
        cd "$ROOT_DIR"
        return
    fi
    echo "Pull Request créée avec succès dans $dir."

    # Extraction de l'URL de la PR à partir de la sortie
    PR_URL=$(echo "$PR_CREATE_OUTPUT" | grep -Eo 'https://github.com/[^ ]+/pull/[0-9]+')
    echo "URL de la Pull Request: $PR_URL"

    # Récupération de l'ID de la PR pour l'utiliser avec le merge
    PR_NUMBER=$(basename "$PR_URL")
    if [[ $4 = "--silent" ]]; then
        if [[ $5 = "--merge" ]]; then
            echo "$PR_NUMBER 🚀"
            echo "🚀 Auto Merge !"

            gh pr merge --merge "$PR_NUMBER"
            if [[ $? -eq 0 ]]; then
                echo "La Pull Request a été fusionnée avec succès 🚀"
            else
                echo "Échec de la fusion de la Pull Request dans $dir. Veuillez vérifier manuellement."
            fi
        fi
    else
      if [[ $4 = "--auto-merge" ]]; then
         gh pr merge --merge "$PR_NUMBER"
            if [[ $? -eq 0 ]]; then
                echo "La Pull Request a été fusionnée avec succès dans $dir."
            else
                echo "Échec de la fusion de la Pull Request dans $dir. Veuillez vérifier manuellement."
            fi
        else
        # Demander confirmation avant de merger la PR
            if confirm "Voulez-vous vraiment fusionner cette Pull Request dans $dir ?"; then
                gh pr merge --merge "$PR_NUMBER"
                if [[ $? -eq 0 ]]; then
                    echo "La Pull Request a été fusionnée avec succès dans $dir."
                else
                    echo "Échec de la fusion de la Pull Request dans $dir. Veuillez vérifier manuellement."
                fi
            else
                echo "Fusion annulée pour $dir."
            fi
        fi
    fi
    cd "$ROOT_DIR"
}


## Main
echo "🚀 Welcome developers !! 🚀"
echo "🚀 This script will help you to create Pull Request and merge it automatically! 🚀"

if ! command -v gh &> /dev/null; then
    echo "git cli n'est pas installé."
    echo "Installation de git cli! 🚀"
    sudo mkdir -p -m 755 /etc/apt/keyrings && wget -qO- https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null \
    && sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
    && sudo apt update \
    && sudo apt install gh -y
    if [[ $? -eq 0 ]]; then
        echo "git CLI installé avec succès."
        exit 0
    else
        echo "Échec de l'installation de git CLI. Veuillez vérifier manuellement."
        exit 1
    fi
fi

# Mode multiple
if [[ "$1" == "--multiple" ]]; then
    SOURCE_BRANCH_NAME=$2
    DEST_BRANCH_NAME=$3
    if [ "$#" -lt 3 ] || [ "$3" = "--silent" ]  || [ "$3" = "--merge" ]; then
        echo "Usage for merge multiple submodule: $0 --multiple <source-branch> <dest-branch> [--silent] [--merge]"
        echo "Please make $0 --help for more information"
        exit 1
    fi
    if [ "$4" == "--silent" ] && [ "$5" == "" ]; then
        echo "Usage for merge multiple submodule: $0 --multiple <source-branch> <dest-branch> [--silent] [--merge]"
        echo "Please make $0 --help for more information"
    fi
    for dir in MS-* frontend-*/src/components/COMPONENTS-*; do
        if [ -d "$dir" ]; then
            check_and_multiple_pr "$dir" "$SOURCE_BRANCH_NAME" "$DEST_BRANCH_NAME" $4 $5
        fi
    done
    exit 0
fi
# Vérifie si le nombre d'arguments est correct
if [ "$#" -lt 2 ] || [ "$1" = '-h' ] || [ "$1" = "--help" ] && [ "$1" != "--cicd" ]; then
    echo "Help guide !"
    echo "-----------------------------------------------------------------------------"
    echo "Sample usage: $0 <source-branch> <dest-branch> [ --auto-merge ]"
    echo "Example : ./gh-pr.sh backlog-0 dev-mns"
    echo "This command create PR and prompt confirm for Merge backlog-0 to dev-mns"
    echo "Example : ./gh-pr.sh backlog-0 dev-mns --auto-merge"
    echo "This command create PR and Merge automatically backlog-0 to dev-mns"
    echo "-----------------------------------------------------------------------------"
    echo "Usage for merge multiple submodule: $0 --multiple <source-branch> <dest-branch> [--silent] [--merge]"
    echo "Example : ./gh-pr.sh --multiple backlog-0 dev-mns --silent --merge"
    echo "This command create PR and Merge backlog-0 to dev-mns without confirmation for merge, merge automatically"
    echo "Example : ./gh-pr.sh --multiple backlog-0 dev-mns"
    echo "This command create PR and Merge backlog-0 to dev-mns and prompt confirmation for merge request"
    exit 1
fi

if [ "$1" = "--cicd" ]; then
echo "CI/CD mode! 🚀"
    if ! command -v gh &> /dev/null; then
        echo "Installation de git cli! 🚀"
        sudo mkdir -p -m 755 /etc/apt/keyrings && wget -qO- https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null \
        && sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
        && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
        && sudo apt update -y \
        && sudo apt install gh -y
    fi
    targetBranch=$2
    rootDir=$(pwd)
    #Affecte une valeur par défaut si $3 n'est pas défini
    patternFind="${3:-"FT-|backlog-"}"
    for dir in frontend-*/src/components/COMPONENTS-*; do
        if [ -d "$dir" ]; then
            cd "$dir"
            echo "Traitement du répertoire : $dir"
            # Assurez-vous d'avoir la liste à jour des branches
            git fetch --all
             # Lister les branches distantes et filtrer par les préfixes désirés
            branches=$(git branch -r | grep -E "origin/(${patternFind})" | sed 's/origin\///')
            echo "Branches distantes : $branches" pour $dir
            cd "$rootDir"
            # Lister les branches 
            for branch in $branches; do
                branch=$(echo "$branch" | xargs)  # Nettoyer les espaces
                echo "Fusion de $branch dans $targetBranch pour $dir..."
                check_and_multiple_pr "$dir" "$branch" "$targetBranch" $4 $5
            done
        fi
    done
    exit 0

fi


# Demander à l'utilisateur de choisir entre MS_DIR et COMPONENTS_DIR
echo "Voulez-vous faire une pull request sur un Microservice ou un MicroFrontend ?"
select OPTION in "MS_DIR" "COMPONENTS_DIR"; do
    case $OPTION in
        MS_DIR )
            # Sélection du dossier MS-
            echo "Sélectionnez le dossier MS- :"
            MS_DIRS=(MS-*/)
            select MS_DIR in "${MS_DIRS[@]}"; do
                [ -n "$MS_DIR" ] && break
                echo "Sélection invalide. Veuillez réessayer."
            done
            DIRECTORY=$MS_DIR
            break
            ;;
        COMPONENTS_DIR )
            # Sélection du composant COMPONENTS-
            echo "Sélectionnez le composant COMPONENTS- :"
            COMPONENTS_DIRS=(frontend-*/src/components/COMPONENTS-*/)
            select COMPONENTS_DIR in "${COMPONENTS_DIRS[@]}"; do
                [ -n "$COMPONENTS_DIR" ] && break
                echo "Sélection invalide. Veuillez réessayer."
            done
            DIRECTORY=$COMPONENTS_DIR
            break
            ;;
        * ) echo "Option invalide. Veuillez choisir 1 pour MS_DIR ou 2 pour COMPONENTS_DIR.";;
    esac
done

echo "Vous avez sélectionné : $DIRECTORY"

# Se déplacer vers le répertoire sélectionné
# cd "$DIRECTORY" || exit 1

# cd "$3"

SOURCE_BRANCH=$1
DEST_BRANCH=$2


check_and_pr_and_merge "$SOURCE_BRANCH" "$DEST_BRANCH" "$DIRECTORY" $3
exit 1
