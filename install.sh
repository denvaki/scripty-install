#!/bin/sh

currentDir=$(pwd)

[ -d $currentDir/nginx.conf/scripty ] && rm -rf $currentDir/nginx.conf/scripty

# check required commands
ngExists=$(command -v ng)
dockerExists=$(command -v docker)
gitExists=$(command -v git)
npmExists=$(command -v npm)
dockerComposeExists=$(command -v docker-compose)

if [ -z "${ngExists}" ] || [ -z "${dockerExists}" ] || [ -z "${gitExists}" ] || [ -z "${npmExists}" ] || [ -z "${dockerComposeExists}" ]; then
    echo "docker, docker-compose, ng(angular cli tool), npm or git not installed, please install them first, exiting..."
    exit 1
fi

if [ ! -s "Dockerfile" ]; then
    echo "no Dockerfile in current directory($(pwd)), exiting..."
    exit 1
fi

git pull


scripty_backendRepo="https://github.com/denvaki/scripty-backend.git"
scripty_frontendRepo="https://github.com/denvaki/scripty-frontend.git"


backendProjectName=$(echo ${scripty_backendRepo##*\/} | sed 's/.git//g' )
frontendProjectName=$(echo ${scripty_frontendRepo##*\/} | sed 's/.git//g' )

#checking and updating local frontend repo
if [ -d "${backendProjectName}" ]; then
    cd ${backendProjectName}
    echo "using existing local repository($(pwd))"
    changelog_backend=$(git pull)
    if [ $? != 0 ]; then
        echo "failed to pull backend repository, exiting..."
        exit 1
    fi
else
    echo "no backend repository exists in current directory($(pwd)). getting from remote repo"
    git clone "${scripty_backendRepo}"
    if [ $? != 0 ]; then
        echo "failed to clone backend repository, exiting..."
        exit 1
    fi

fi
cd ${currentDir}
echo "local backend repository is updated!" && echo 


#checking and updating local frontend repo
if [ -d "${frontendProjectName}" ]; then
    cd ${frontendProjectName}
    echo "using existing local repository($(pwd))"
    changelog_frontend=$(git pull)
    
    if [ $? != 0 ]; then
        echo "failed to pull frontend repository, exiting..."
        exit 1
    fi
else
    echo "no frontend repository exists in current directory($(pwd)). getting from remote repo"
    git clone "${scripty_frontendRepo}"
    if [ $? != 0 ]; then
        echo "failed to clone frontend repository, exiting..."
        exit 1
    fi

fi
cd ${currentDir}
echo "local frontend repository is updated!" && echo

#building frontend(site)
cd ${frontendProjectName}
npm list @angular-devkit/build-angular 2>&1 >/dev/null
if [ $? -ne 0 ]; then 
    npm install --save-dev @angular-devkit/build-angular
fi

# if something was changed in repository
if [ "${changelog_frontend}" != "Already up to date." ] || [ ! -d dist/scripty ]; then
    ng build --prod
fi

if [ $? != 0 ]; then
    echo "failed to build frontend, exiting..."
    exit 1
fi
if [ ! -d dist/scripty ]; then
    echo "dist or dist/scripty directory not exists after build, exiting..."
    exit 1
fi

#copying builded files
if [ -d $currentDir/nginx.conf ]; then
    cp -r dist/scripty $currentDir/nginx.conf
fi
cd ${currentDir}

# building Docker image
echo "starting to build Docker image from Dockerfile..."

docker-compose up -d --build