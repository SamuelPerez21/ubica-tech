#!/bin/bash

DB_IMAGE="postgres10"
BACKEND_IMAGE="webapp" #"geocitizen"
FRONTEND_IMAGE="geocitizen-front"
DB_DFILE="./docker/psql10.Dockerfile"
BACKEND_DFILE="./docker/webapp_lite.Dockerfile" #"./docker/backend_lite.Dockerfile"
FRONTEND_DFILE="./docker/frontend_lite.Dockerfile"

CUSTOM_URL=0
FORCE_BUILD=0
CHECK_IF_RUNNING=0
SKIP_FRONTEND=0

FRONT_PORT=8081
PG_NAME="ss_demo_1"
PG_URL="jdbc:postgresql://localhost:5432/${PG_NAME}"
TC_HOME='/usr/local/tomcat' #'/opt/tomcat/apache-tomcat-9.0.100'

for arg in "$@"; do
    if [[ "$arg" = "--help" ]]; then
        echo "Usage: ./docker-start.sh [OPTIONS]"
        echo "  Start the Geocitizen project with Docker."
        echo -e "\nOptions:"
        echo -e "  -R                 Remove all containers before starting."
        echo -e "  -h URL             Use a custom database hosted on URL."
        echo -e "  -n NAME            Use a custom NAME for the database."
        echo -e "  -b                 Force the build of the images before running."
        echo -e "  -s                 Skip the containers already running."
        echo -e "  -i                 Ignore frontend. Useful for Webapp testing."
        echo -e "  --help             Show this help message and exit.\n"
        exit 0
    fi
done

while getopts "Rh:n:bsi" opt; do
    case $opt in
        R)  ./dstop.sh --all;;
        h)
            CUSTOM_URL=1
            PG_URL=$OPTARG
            ;;
        n)  PG_NAME=$OPTARG;;
        b)  FORCE_BUILD=1;;
        s)  CHECK_IF_RUNNING=1;;
        i)  SKIP_FRONTEND=1;;
        \?)
            echo -e "Invalid option: -$OPTARG\n"
            exit 1
            ;;
    esac
done

check_success() {
    local status=$1
    local message=$2

    if [[ $status -ne 0 ]]; then
        echo -e "\n[ERROR] $message"
        exit $status
    fi
}

build_image_if_not_exists() {
    local image=$1
    local dockerfile=$2

    if [[ $FORCE_BUILD = 1 || "$(docker images -q $image 2> /dev/null)" = "" ]]; then
        if [[ $FORCE_BUILD = 1 ]]; then
            echo "Forcing the build of image '$image'..."
        else
            echo "Image '$image' not found. Building with Docker..."
        fi
        docker build -t $image -f $dockerfile .
        check_success $? "Error building image '$image'! 💥 Exiting..."
    else
        echo "Image '$image' already exists. Skipping build."
    fi
}

check_db_running() {
    if [[ $CUSTOM_URL = 1 ]]; then
        echo -e "Custom database URL provided. Skipping database check..."
        return 0
    fi
    if [[ "$(docker ps -q -f name=${DB_IMAGE}v1)" ]]; then
        echo -e "Database container is already running. Skipping..."
    else
        echo -e "Database container not found. Starting..."
        build_image_if_not_exists $DB_IMAGE $DB_DFILE
        docker run -d -p 5432:5432 --name ${DB_IMAGE}v1 -e POSTGRES_DB=$PG_NAME $DB_IMAGE
        check_success $? "Error starting Database container! 💥 Exiting..."
        echo -e "Database container started successfully!"
    fi
    return 0
}

echo -e "Starting the Geocitizen project with Docker! 🚀\n"

check_db_running
if [[ $? != 0 && $CHECK_IF_RUNNING = 0 ]] || \
   [[ "$(docker ps -aq -f name=${BACKEND_IMAGE}v1)" && $CHECK_IF_RUNNING = 0 ]] || \
   [[ "$(docker ps -aq -f name=${FRONTEND_IMAGE}v1)" && $CHECK_IF_RUNNING = 0 ]]; then
    echo -e "[WARNING] Mission aborted! 🛑\n"
    echo -e "One or more containers are already running. Check it out with 'docker ps -a'"
    echo -e "Consider stopping them before starting new ones, or skip this with '-s' flag!\n"
    exit 117
fi

if [[ $SKIP_FRONTEND = 0 ]]; then
    build_image_if_not_exists $FRONTEND_IMAGE $FRONTEND_DFILE
fi

if [[ $CHECK_IF_RUNNING = 1 && $(docker ps -q -f name=${BACKEND_IMAGE}v1) ]]; then
    echo -e "\nBackend container already running. Skipping..."
else
    echo -ne "\nStarting Backend container with hash="
    if [[ $CUSTOM_URL = 0 ]]; then
        DOCKER_QUERY='{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}'
        DB_CONTAINER_IP=$(docker inspect --format="$DOCKER_QUERY" ${DB_IMAGE}v1)
        PG_URL="jdbc:postgresql://${DB_CONTAINER_IP}:5432/${PG_NAME}"
    fi
    docker build -t $BACKEND_IMAGE -f $BACKEND_DFILE --build-arg DATABASE_URL=$PG_URL .
    docker run -d -p 8080:8080 --name ${BACKEND_IMAGE}v1 \
        -v ./docker/backend-config/tomcat-users.xml:${TC_HOME}/conf/tomcat-users.xml \
        -v ./docker/backend-config/context.xml:${TC_HOME}/webapps/manager/META-INF/context.xml \
        -e DB_URL=$PG_URL -e REFERENCEURL=$PG_URL -e URL=$PG_URL $BACKEND_IMAGE | head -c 12
    check_success $? "Error starting Backend container! 💥 Exiting..."
fi
echo -e "\nBackend container available. Webapp deployed to [/citizen]"

if [[ $CHECK_IF_RUNNING = 1 && $(docker ps -q -f name=${FRONTEND_IMAGE}v1) ]]; then
    echo -e "\nFrontend container already running. Skipping..."
else
    if [[ $SKIP_FRONTEND = 1 ]]; then
        echo -e "\nSkipping Frontend container because of flags..."
        FRONT_PORT=8080
    else
        echo -ne "\nStarting Frontend container with hash="
        docker run -d -p 8081:8081 --name ${FRONTEND_IMAGE}v1 $FRONTEND_IMAGE | head -c 12
        check_success $? "Error starting Frontend container! 💥 Exiting..."
    fi
fi
echo -e "\nFrontend is available on http://localhost:$FRONT_PORT/#/"

echo -e "\nAll containers started successfully! 🚀\n"