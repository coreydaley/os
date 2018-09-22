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

# Displays a formatted message to the console
# Example: message "LEVEL" "This is a message"
# Output: [OS] [LEVEL] This is a message
function message() {
  echo "[OS] [$1] $2"
}

# Make sure that Origin is checked out into a valid location
OS_GO_DIR=$GOPATH/src/github.com/openshift/origin
if [ -e $OS_GO_DIR ]; then
  OS_PATH=$OS_GO_DIR
else
  message "ERROR" "It looks like $OS_GO_DIR doesn't exist."
  exit 1
fi

# Define some standard file and folder locations
OS_OUTPUT_PATH=$OS_GO_DIR/_output
OS_TEMPLATE_PATH=$OS_GO_DIR/examples
OS_BIN_PATH=$OS_OUTPUT_PATH/local/bin/linux/amd64
OS_CONFIG_PATH=$OS_GO_DIR/openshift.local.clusterup
OS_KUBE_CONFIG_PATH=$OS_CONFIG_PATH/kube-apiserver/admin.kubeconfig

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
    sudo rm -rf $1
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
    $0 symlink-binaries
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
    make clean
  ;;
  # Removes all containers, volumes, and images from docker
  # and cleans up used space
  cleandocker|cd)
    message "INFO" "Cleaning Docker"
    $0 stop
    if [ $(docker ps -a | grep openshift | wc -l) -gt 0 ]; then
      message "INFO" "Removing OpenShift containers"
      docker ps -a | grep openshift | awk '{print $1}' | xargs docker rm -vf
    fi
    if [ $(docker images | grep openshift | wc -l) -gt 0 ]; then
      message "INFO" "Removing OpenShift images"
      docker images | grep openshift | awk '{print $3}' | xargs docker rmi -f
    fi
    message "INFO" "Pruning unused volumes"
    docker volume prune -f
    message "INFO" "Pruning unused data"
    docker system prune -f
  ;;
  # Removes the configuration files generated when starting origin
  cleanconfig|cc)
    $0 stop
    message "INFO" "Cleaning Cluster Up Configuration"
    message "INFO" "Unmounting volumes"
    for i in $(mount | grep openshift | awk '{ print $3}'); do sudo umount "$i"; done
    message "INFO" "Removing ${OS_CONFIG_PATH}"
    delete_folder_if_exists $OS_CONFIG_PATH
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
    # FOCUS="$2" test/extended/core.sh
    KUBECONFIG=/home/${USER}/go/src/github.com/openshift/origin/openshift.local.clusterup/openshift-controller-manager/admin.kubeconfig FOCUS=$2 TEST_ONLY=true test/extended/core.sh
  ;;
  # Start Origin
  start)
    $OS_BIN_PATH/oc cluster up --tag=latest --server-loglevel=5
  ;;
  # Restart (or reload) Origin
  restart|reload)
    $0 stop
    $0 cleanconfig
    $0 build
    $0 start
  ;;
  # Stops Origin
  stop)
    message "INFO" "Stopping OpenShift"
    $OS_BIN_PATH/oc cluster down
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
      python hack/build-local-images.py $2
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
    PERMISSIVE_GO=y hack/verify-gofmt.sh | xargs -n 1 gofmt -s -w
  ;;
  # Setup the router
  router)
    message "INFO" "Setting up router"
    run_as_admin "oc adm policy add-scc-to-user hostnetwork -z router"
    run_as_admin "oc adm router"
    run_as_admin "oc rollout latest dc/router"
  ;;
  # Setup the registry
  registry)
    message "INFO" "Setting up registry"
    run_as_admin "oc adm registry"
  ;;
  # Setup the example imagestreams and templates
  ist)
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
  ;;
  # Setup the webconsole
  # webconsole)
  #   message "INFO" "Setting up webconsole"
  #   run_as_admin "oc adm policy add-cluster-role-to-user cluster-admin admin"
  #   oc login -u admin
  #   source ./contrib/oc-environment.sh
  #   ./bin/bridge
  # ;;
  # Do some basic setup for Origin, must have run start first
  # Sets up the registry, router, and loads the example templates
  # and imagestreams
  setup)
    $0 ist
    $0 registry
    $0 router
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
