#!/bin/bash
URL_SNIPPETS_VSCODE="https://raw.githubusercontent.com/aidalinfo/DEV-TOOLBOX/main/vscode/global-snippets.code-snippets"
SNIPPETS_LOCAL_NAME="aidalinfo-global.code-snippets"

submoduleAction(){
  echo " 👉 On entre dans la fonction submoduleAction avec l'argument $1"
  currentDir=`pwd`
  echo " 👉 On est dans le répertoire $currentDir"
  echo " 🤖 On initialise et update les submodules "
  git submodule init
  git submodule update
  echo " 🤖 On passe sur la branche main "
  git checkout main
  echo " 🤖 On pull"
  git pull
  if [ -n "${1}" ] && [ "${1}" = "branch" ]; then
    git checkout $2
  fi
  submodules=`cat .gitmodules|grep "path ="|sed -e 's/path = /\n/g'|sed -r '/^\s*$/d'`
  echo " 👉 On a trouvé les submodules suivants : $submodules"
  while read -r submodule; do
    echo " 👉👉 On est dans $currentDir et on a trouvé le submodule: $submodule"
    echo " 🤖 On va dans le répertoire $submodule"
    cd $submodule
    echo " 🤖 On passe sur la branche main "
    git checkout main
    echo " 🤖 On pull"
    git pull
    if [ -n "${1}" ] && [ "${1}" = "branch" ]; then
      if [ -n "${2}" ] && [ -n "${3}" ]; then
        echo " 🤖 On passe sur la branche $2 ou $3"
        git checkout $2 || git checkout $3
      else
       git checkout $2
      fi
      git pull
    fi
    if [ -f .gitmodules ]; then
      echo " 👉👉 Il y a un fichier .gitmodules"
      echo " 🤖🤖 RECURSIVITE !"
      #On attend que le process soit executé pour continuer
      submoduleAction $1 $2 $3&
      process_id=$!
      wait $process_id
    fi
      echo " 🤖 On retourne dans le répertoire $currentDir"
      cd $currentDir
  done <<< $submodules
}

npmAction(){
  for d in */ ; do
      echo "$d"
      cd $d
      if [ -f package.json ]; then
        echo "package.json existe, on installe"
        # --no-save permet de ne pas toucher au package-lock.json
        npm install --no-save
      fi
      if [ -f .gitmodules ] && [ -n "${2}" ] && [ "${2}" = "all" ]; then
      # if [ -f .gitmodules && $2 == "all" ]; then
        echo ".gitmodules existe, on installe"
        #On met à jour les sous submodules
        git submodule init
        git submodule update
      fi
      cd ..
  done
}

tagAction(){
  for d in */ ; do
    echo "$d"
    cd $d
    if [ -f package.json ]; then
      echo "package.json existe, on tag"
    
      git tag -a $1 -m $2 && git push --tags
    fi
    cd ..
  done
}

vscodeAction(){
err=$(curl --write-out '%{http_code}' $URL_SNIPPETS_VSCODE -o  ~/.config/Code/User/snippets/$SNIPPETS_LOCAL_NAME)
if [ "$err" -ne "200" ]
then
	echo "Il y a eu un problème lors du téléchargement du fichier $SNIPPETS_LOCAL_NAME (HTTO ERROR $err)."
	if [ -f ~/.config/Code/User/snippets/$SNIPPETS_LOCAL_NAME ]
	then
		rm -rf  ~/.config/Code/User/snippets/$SNIPPETS_LOCAL_NAME
	fi
	exit 2
fi
}

if [[ -z $1 ]]; then
  echo " 🤘🤘🤘 Hello ! Il est attendu un paramètre pour ce script 🤘🤘🤘 "
  echo "Liste des paramètres :"
  echo " 👉 install : Installe l'ensemble des dépendances des différents MicroServices du projet"
  echo "    ⏩ sans argument = On initialise les submodules (branche main)"
  echo "    ⏩ branch [nomDeLaBranche] [nomDeLaBrancheDeRepli] = On initialise les submodules sur la branche voulue, il est possible de définir un branche de repli, si les branches n'existent pas, on reste sur main"
  echo "    ⏩ full = On initialise les submodules (main) et on installe les dépendances nodes"
  echo "    ⏩ npm = On installe les dépendances nodes sans toucher aux branches"
  echo " 👉 update : Met à jour l'ensemble des dépendances des différents MicroServices du projet"
  echo " 👉 hostUpdate:[root] Inscrit fileStorage dans le host de votre machine afin de pouvoir utiliser le stockage de fichier en local"
  echo " 👉 vscode: Récupère les personnalisations de vsCode (Snippets, ...) et les ajoutes au profil de l'utilisateur connecté "
  echo " 👉 tag <vX.X.X> <'message de tag'> : Permet de tagger l'ensemble des MS sur un nouveau tag (attention automate CI CD Github action) "
  exit
fi

if [ $1 == "install" ]; then
  echo " 🚀🤖 On installe le projet 🤖🚀"

  if [ ! -n "${2}" ]; then
    echo " 🤖 Pas d'argument : On initialise les submodules (branche main)"
    submoduleAction
  fi
  if [ -n "${2}" ] && [ "${2}" = "branch" ]; then
    if [ -n "${3}" ]; then
      echo " 🤖 On initialise les submodules et on essaye de passer sur la branche $3"
      if [ -n "${4}" ]; then
        echo "Si la branche n'existe pas, on cherche à basculer sur $4 avant main"
      fi
      submoduleAction $2 $3 $4
    else
      echo " 🤖 Il manque un argument !"
    fi

  fi
  if [ -n "${2}" ] && [ "${2}" = "full" ]; then
    echo " 🤖 On initialise les submodules (main) et on installe les dépendances nodes"
    #On attend que le process soit executé pour continuer
    submoduleAction &
    process_id=$!
    wait $process_id
    npmAction
  fi
  if [ -n "${2}" ] && [ "${2}" = "npm" ]; then
    echo " 🤖 On installe les dépendances nodes sans toucher aux branches"
    #On attend que le process soit executé pour continuer
    npmAction
  fi
  
fi

if [ $1 == "update" ]; then
  echo "On update le projet, pensez à commit et avant l'update pour rétropédaler en cas de soucis!"
  git submodule update
  for d in */ ; do
      echo "$d"
      cd $d

      if [ -f package.json ]; then
        echo "package.json existe, on met à jour"
        npm update
      fi
      cd ..
  done
fi

if [ $1 == "hostUpdate" ]; then
  echo "Inscrit fileStorage dans le host de votre machine afin de pouvoir utiliser le stockage de fichier en local"
  echo "127.0.0.1       filesstorage" >> /etc/hosts
  echo "Inscrit test[123].local dans le host de votre machine afin de pouvoir tester l'accès à l'appli depuis différentes URL"
  echo "127.0.0.1       test1.local" >> /etc/hosts
  echo "127.0.0.1       test2.local" >> /etc/hosts
  echo "127.0.0.1       test3.local" >> /etc/hosts
fi

if [ $1 == "vscode" ]; then
  echo "Récupère les personnalisations de vsCode (Snippets, ...) et les ajoutes au profil de l'utilisateur connecté"
  vscodeAction
fi

if [ $1 == "tag" ]; then
  echo " 🚀🤖 On tag les différents repository 🤖🚀"

  if [ ! -n "${2}" ]  || [ ! -n "${3}" ]; then
    echo " 🤖 Il manque un arguement : BYE BYE"
    exit
  fi

   tagAction $2 $3



fi
