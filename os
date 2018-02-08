#! /usr/bin/env bash

#               OOOOOOOOO        SSSSSSSSSSSSSSS
#             OO:::::::::OO    SS:::::::::::::::S
#           OO:::::::::::::OO S:::::SSSSSS::::::S
#          O:::::::OOO:::::::OS:::::S     SSSSSSS
#          O::::::O   O::::::OS:::::S
#          O:::::O     O:::::OS:::::S
#          O:::::O     O:::::O S::::SSSS
#          O:::::O     O:::::O  SS::::::SSSSS
#          O:::::O     O:::::O    SSS::::::::SS
#          O:::::O     O:::::O       SSSSSS::::S
#          O:::::O     O:::::O            S:::::S
#          O::::::O   O::::::O            S:::::S
#          O:::::::OOO:::::::OSSSSSSS     S:::::S
#           OO:::::::::::::OO S::::::SSSSSS:::::S
#             OO:::::::::OO   S:::::::::::::::SS
#               OOOOOOOOO      SSSSSSSSSSSSSSS
#
#                 github.com/coreydaley/os
#
# A script to make OpenShift Origin development more pleasurable
#

#
# OpenShift Origin
# https://github.com/openshift/origin
#

#
# This script assumes origin is checked out into a standard Go
# package structure and that $GOPATH is set correctly
#

# https://stackoverflow.com/questions/59895/getting-the-source-directory-of-a-bash-script-from-within
SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do
  DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
done
CANONICAL_DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"

# Displays a formatted message to the console
# Example: message "LEVEL" "This is a message"
# Output: [OS] [LEVEL] This is a message
function message() {
  echo "[OS] [$1] $2"
}

# Make sure that Origin is checked out into a valid location
OS_GO_DIR=$GOPATH/src/github.com/openshift/origin
if [ -e $OS_GO_DIR ]; then
  message "INFO" "Using $OS_GO_DIR"
  OS_PATH=$OS_GO_DIR
else
  message "ERROR" "It looks like $OS_GO_DIR doesn't exist."
  exit 1
fi

# Define some standard file and folder locations
OS_OUTPUT_PATH=$OS_PATH/_output
OS_TEMPLATE_PATH=$OS_PATH/examples
OS_BIN_PATH=$OS_OUTPUT_PATH/local/bin/linux/amd64
OS_CONFIG_PATH=$OS_BIN_PATH/openshift.local.config
OS_KUBE_CONFIG_PATH=$OS_CONFIG_PATH/master/admin.kubeconfig
KUBE_CONFIG_DIR=$HOME/.kube
KUBE_CONFIG_PATH=$KUBE_CONFIG_DIR/config


# Make sure that the ~/.kube directory exists
if [ ! -d $KUBE_CONFIG_DIR ]; then
  message "INFO" "Creating $KUBE_CONFIG_DIR"
  mkdir $KUBE_CONFIG_DIR
fi

# Make sure that these files exist
# in the correct location
FILES=(
"volumes.yaml"
"console-config.yaml"
)
missing_files=false
for FILE in ${FILES[@]}
do
  if [ ! -e ${CANONICAL_DIR}/files/${FILE} ]; then
    missing_files=true
    message "ERROR" "Missing ${CANONICAL_DIR}/files/${FILE}"
  fi

done
if $missing_files; then
  message "" "Create the above missing files and try running the command again."
  exit
fi

# Delete file if it exists
function delete_if_exists() {
  if [ -e $1 ]; then
    message "INFO" "Deleting $1"
    rm $1
  fi
}

# Delete folder if it exists
function delete_folder_if_exists() {
  if [ -e $1 ]; then
    message "INFO" "Deleting $1"
    rm -r $1
  fi
}

# Run command as system:admin
function run_as_admin() {
  message "INFO" "Running command as system:admin: ${1}"
  $OS_BIN_PATH/${1} --config=$OS_KUBE_CONFIG_PATH
}

case "$1" in
  # Deletes all resources for the currently logged in user
  # effectively resetting your project
  reset)
    message "INFO" "Resetting current project"
    $OS_BIN_PATH/oc delete all --all
    $OS_BIN_PATH/oc delete templates --all
    $OS_BIN_PATH/oc delete templateinstances --all
    $OS_BIN_PATH/oc delete configmaps --all
    $OS_BIN_PATH/oc delete secrets --all
    $OS_BIN_PATH/oc delete pvc --all
  ;;
  # Runs the make build command
  build)
    message "INFO" "Running make build"
    make build
  ;;
  # Runs the make verify command
  verify)
    message "INFO" "Running make verify"
    make verify
  ;;
  # Runs the make update command
  update)
    message "INFO" "Running make update"
    make update
  ;;
  # Stops openshift, removes the contents of the ~/.kube directory
  # and runs make clean
  clean)
    $0 stop
    message "INFO" "Cleaning OpenShift"
    rm -rf $KUBE_CONFIG_DIR/*
    sudo make clean
  ;;
  # Removes all containers, volumes, and images from docker
  # and cleans up used space
  cleandocker|cd)
    message "INFO" "Cleaning Docker"
    if [ $(docker ps -q | wc -l) -gt 0 ]; then
      docker stop $(docker ps -q)
    fi
    if [ $(docker ps -aq | wc -l) -gt 0 ]; then
      docker rm  -vf $(docker ps -a -q)
    fi
    if [ $(docker images -q | wc -l) -gt 0 ]; then
      docker rmi -f  $(docker images -q)
    fi
    docker volume rm $(docker volume ls -qf dangling=true)
    docker volume prune -f
    docker system prune -a -f
  ;;
  # Removes the configuration files generated when starting origin
  cleanconfig|cc)
    $0 stop
    message "INFO" "Cleaning OpenShift Configuration"
    delete_folder_if_exists $OS_CONFIG_PATH/openshift.local.config
    delete_folder_if_exists $OS_CONFIG_PATH/openshift.local.etcd
    delete_folder_if_exists $OS_CONFIG_PATH/openshift.local.volumes
  ;;
  # Runs all of the various clean commands
  cleanall|ca)
    message "INFO" "Cleaning everything"
    $0 clean
    $0 cleandocker
    $0 cleanconfig
  ;;
  # Run Unit Tests, accepts package and test name as arguments
  # Documentation: https://github.com/openshift/origin/blob/master/HACKING.md#unit-tests
  # Example: os test pkg/foo/bar
  # Example: os test pkg/foo/bar MyTestName
  test|t)
    message "INFO" "Running unit test"
    COVERAGE_OUTPUT_DIR='/tmp/ostestcoverage' hack/test-go.sh $2 -test.run=$3
  ;;
  # Run CLI Integration Tests, accepts a regex as an argument
  # Example: os testcmd newapp
  testcmd|tc)
    message "INFO" "Running CLI Integration Test"
    hack/test-cmd.sh "$2"
  ;;
  # Run the Integration Tests, accepts a regex
  # Documentation: https://github.com/openshift/origin/blob/master/HACKING.md#integration-tests
  # Example: os testintegration FooBar
  testintegration|ti)
    message "INFO" "Running Integration Test"
    delete_if_exists _output/local/bin/linux/amd64/integration.test
    hack/test-integration.sh "$2"
  ;;
  # Run End-to-End (e2e) Tests, does not accept any arguments
  # Documentation: https://github.com/openshift/origin/blob/master/HACKING.md#end-to-end-e2e-and-extended-tests
  testendtoend|te2e)
    message "INFO" "Running End-To-End (e2e) Test"
    hack/test-end-to-end.sh
  ;;
  # Run Extended Tests, accepts a regex that is passed to --ginkgo.focus
  # Documentation: https://github.com/openshift/origin/blob/master/HACKING.md#end-to-end-e2e-and-extended-tests
  # Example: os testextended FooBar
  testextended|te)
    message "INFO" "Running Extended Test"
    delete_if_exists _output/local/bin/linux/amd64/extended.test
    FOCUS="$2" test/extended/core.sh
  ;;
  # Start (or restart) Origin
  # Does a bunch of setup if you are starting with a clean environment
  start|restart|reload)
    $0 stop
    $0 build
    pushd $OS_BIN_PATH >> /dev/null
    if [ ! -f $OS_CONFIG_PATH/master/master-config.yaml ]; then
      message "INFO" "Creating master and node configuration directories"
      sudo $OS_BIN_PATH/openshift start --write-config=$OS_CONFIG_PATH --latest-images=true
      sudo sed -i -e 's/router.default.svc.cluster.local/127.0.0.1.nip.io/' $OS_CONFIG_PATH/master/master-config.yaml
      mkdir -p $OS_CONFIG_PATH
      sudo chmod +r $OS_KUBE_CONFIG_PATH
      sudo cp $OS_KUBE_CONFIG_PATH $KUBE_CONFIG_PATH
      sudo chown $USER:$USER $OS_KUBE_CONFIG_PATH
      sudo chown $USER:$USER $KUBE_CONFIG_PATH
    fi
    message "INFO" "Starting OpenShift"
    sudo $OS_BIN_PATH/openshift start --loglevel=5 --master-config=$OS_CONFIG_PATH/master/master-config.yaml --node-config=$OS_CONFIG_PATH/node-`hostname`/node-config.yaml > $OS_OUTPUT_PATH/openshift-dev.log  2>&1 &
    popd >> /dev/null
    $0 symlink-binaries
  ;;
  # Stops Origin
  stop)
    message "INFO" "Stopping OpenShift"
    sudo pkill -x openshift
    docker ps | awk 'index($NF,"k8s_")==1 { print $1 }' | xargs -l -r docker stop
    mount | grep "openshift.local.volumes" | awk '{ print $3}' | xargs -l -r sudo umount
  ;;
  # Symlinks the Origin binaries into ~/bin
  symlink-binaries|sb)
    message "INFO" "Symlinking OpenShift binaries"
    BINARIES=(
              "oc"
              "openshift"
    )
    for b in ${BINARIES[@]}
    do
      message "INFO" "Symlinking ${OS_BIN_PATH}/${b} to ~/bin/${b}"
      ln -sf ${OS_BIN_PATH}/${b} ~/bin/${b}
    done
  ;;
  # Build images based on the currently checked out code and push them to the registry
  build-images|bi)
      message "INFO" "Building images"
      $0 build
      hack/build-local-images.py
  ;;
  # Do some basic setup for Origin, must have run start first
  # Sets up the registry, router, web console, and loads the default templates
  # Also creates some persistent volumes and a user/project based
  # on your user on your workstation
  setup)
    message "INFO" "Setting up OpenShift"
    if [[ ! -z $2 ]]; then
      if ! [[ $2 =~ ^(centos|rhel)$ ]]; then
        message "ERROR" "Option \"$2\" not found, must be one of [centos, rhel]"
        exit 1
      else
        OS=$2
      fi
    else
      OS=centos
    fi

    message "INFO" "Setting up router"
    run_as_admin "oc adm policy add-scc-to-user hostnetwork system:serviceaccount:default:router"
    run_as_admin "oc adm router"
    run_as_admin "oc rollout latest dc/router"

    message "INFO" "Setting up registry"
    run_as_admin "oc adm registry -n default"

    message "INFO" "Setting up webconsole"
    run_as_admin "oc create namespace openshift-web-console"
    run_as_admin "oc project openshift-web-console"
    run_as_admin "oc create -f install/origin-web-console/console-template.yaml"
    oc new-app --template=openshift-web-console -p "API_SERVER_CONFIG=$(cat ${CANONICAL_DIR}/files/console-config.yaml)" --config=$OS_KUBE_CONFIG_PATH

    message "INFO" "Loading ${OS} image streams from examples directory"
    run_as_admin "oc create -f $OS_TEMPLATE_PATH/image-streams/image-streams-${OS}7.json -n openshift"

    message "INFO" "Loading quickstarts and database templates from examples directory"
    LOCATIONS=(
              "jenkins"
              "db-templates"
              "quickstarts"
    )
    for l in ${LOCATIONS[@]}
    do
      for f in $OS_TEMPLATE_PATH/${l}/*.json
      do
        run_as_admin "oc create -f ${f} -n openshift"
      done
    done

    $0 create-volumes
    $0 create-user ${USER}
  ;;
  # Creates a user in Origin with a matching namespace
  # If no username is passed, a user and namespace
  # based on your workstation username is created
  create-user|cu)
    user=$2
    if [[ ! -z $3 ]]; then
      namespace=$3
    else
      namespace=$user
    fi
    message "INFO" "Creating user ${user}"
    run_as_admin "oc create user ${user}"
    run_as_admin "oc create identity anypassword:${user}"
    run_as_admin "oc create useridentitymapping anypassword:${user} ${user}"

    message "INFO" "Creating namespace ${namespace}"
    run_as_admin "oc create namespace ${namespace}"

    message "INFO" "Granting user ${user} access to namespace ${namespace}"
    run_as_admin "oc project ${namespace}"
    run_as_admin "oc adm policy add-role-to-user admin ${user}"
    run_as_admin "oc adm policy add-role-to-user edit -z deployer"
    run_as_admin "oc adm policy add-role-to-user edit -z builder"
    run_as_admin "oc adm policy add-role-to-user edit -z jenkins"
  ;;
  # Creates persistent volumes based on the localvolumes.yaml file
  create-volumes|cv)
    message "INFO" "Creating persistent volumes"
    sudo rm -rf /tmp/volume*
    mkdir /tmp/volume1
    mkdir /tmp/volume2
    mkdir /tmp/volume3
    chmod a+rw /tmp/volume*
    $OS_BIN_PATH/oc create -f ${CANONICAL_DIR}/files/volumes.yaml
  ;;
  # Copies the source-to-image source code into the correct vendor directory for testing
  copys2i)
    cp -R $GOPATH/src/github.com/openshift/source-to-image/* $GOPATH/src/github.com/openshift/origin/vendor/github.com/openshift/source-to-image/
  ;;
  # Copies the api source code into the correct vendor directory for testing
  copyapi)
    cp -R $GOPATH/src/github.com/openshift/api/* $GOPATH/src/github.com/openshift/origin/vendor/github.com/openshift/api/
  ;;
  # Copies the client-go source code into the correct vendor directory for testing
  copyclient-go)
    cp -R $GOPATH/src/github.com/openshift/client-go/* $GOPATH/src/github.com/openshift/origin/vendor/github.com/openshift/client-go/
  ;;
  # Runs the gofmt script on the origin code and fixes any issues
  gofmt|g)
    message "INFO" "Running gofmt"
    PERMISSIVE_GO=y hack/verify-gofmt.sh
    # PERMISSIVE_GO=y hack/verify-gofmt.sh | xargs -n 1 gofmt -s -w

  ;;
  # Logs you into Origin
  # If no username is passed, you are logged in as your workstation user
  # If sys is passed as the username, you are logged in as system:admin
  login|l)
    if [ -z $2 ]; then
      message "INFO" "Logging in as ${USER}"
      oc login --username=${USER} --password=${USER}
      oc project ${USER}
    elif [ $2 == "sys" ]; then
      message "INFO" "Logging in as system:admin"
      oc login -u system:admin
      oc project default
    else
      message "INFO" "Logging in as $2"
      oc login --username=$2 --password=$2
      oc new-project $2
    fi
  ;;
  # Runs the oc completion and oc adm completion commands and
  # copies the files into your home directory.
  # You will still need to source these files in your .bash_profile
  # or similar to get completion on the command line
  completion)
    message "INFO" "Creating CLI completion files"
    oc completion bash > ~/.oc_completion.sh
    oc adm completion bash > ~/.oc_adm_completion.sh
  ;;
  *)
    echo "Usage: $0 start|stop|clean|restart|reload|setup"
    exit 1
esac
exit 0
