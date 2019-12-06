#!/bin/sh

usage() {
cat <<EOF
  Usage: launch-dev-cluster.sh [OPTIONS]...
  Download the OpenShift client and installer and launch a cluster.

  Optional Arguments:
  --cloudconfig      The name of the cloud configuration file to use. i.e. aws, gce, azure

  --cloudconfigsdir  Path to the folder containing the cloud configuration files
                     Defaults to ~/.openshift/configs

  --clusterdir       Path to the folder to use for the files created by the installer.
                     Defaults to ~/openshift/cluster

  --downloader       Which program to use to download the client and installer.  i.e. oc, curl, wget

  --ostype           Override the detected operating system. i.e. linux-gnu, darwin

  --pullsecret       Path to the file containing your pull secrets.  
                     Defaults to ~/.openshift/pull-secret.json

  --payloadhost      Host to download the client/installer from when using the oc downloader.
                     Defaults to registry.svc.ci.openshift.org

  --payloadimage     Image to download from the payloadhost when using the oc downloader.
                     Defaults to ocp/release

  --releaseversion   Version to use of the OpenShift client and installer.
                     Defaults to 4.2.9

  -h, --help         Display this help.

EOF
}

message () {
  printf "%s\n" "$1"
}

while [ "$1" != "" ]; do
    case $1 in
        --cloudconfig )         shift
                                cloudConfig=$1
                                ;;
        --cloudconfigsdir )     shift
                                cloudConfigsDir=$1
                                ;;
        --clusterdir )          shift
                                clusterDir=$1
                                ;;
        --downloader )          shift
                                downloader=$1
                                ;;
        --ostype )              shift
                                osType=$1
                                ;;
        --payloadhost )         shift
                                payloadHost=$1
                                ;;  
        --payloadimage )        shift
                                payloadImage=$1
                                ;;  
        --pullsecret )          shift
                                pullSecret=$1
                                ;;  
        --releaseversion )      shift
                                releaseVersion=$1
                                ;;                              
        -h | --help )           usage
                                exit
                                ;;
        * )                     usage
                                exit 1
    esac
    shift
done

# detect the operating system and set the type for the client and installer
if [[ "$OSTYPE" == "linux-gnu" ]]; then
        osTypeDetected=linux
elif [[ "$OSTYPE" == "darwin"* ]]; then
        osTypeDetected=mac
else
  message "Unable to identify your operating system. Please specify using --ostype"
  exit 1
fi

# set sane defaults for any options that were not specified
cloudConfig=${cloudConfig:-""}
cloudConfigsDir=${cloudConfigsDir:-"${HOME}/.openshift/configs"}
clusterDir=${clusterDir:-"${HOME}/openshift/cluster"}
pullSecret=${pullSecret:-"${HOME}/.openshift/pull-secret.json"}
osType=${osType:=${osTypeDetected}}
releaseVersion=${releaseVersion:-"4.2.9"}
downloader=${downloader:-""}
host=${payloadHost:-"registry.svc.ci.openshift.org"}
image=${payloadImage:-"ocp/release"}
tmpdir=/tmp/openshift-release

# show the user the config that we are going to use
message "---------- Using Configuration ----------"
message "Release Version:        ${releaseVersion}"
message "Operating System:       ${osType}"
message "Cluster Directory:      ${clusterDir}"
message "Pull Secret Location:   ${pullSecret}"
if [ ! -z "$cloudConfig" ]; then
  message "Cloud Config:            ${cloudConfig}"
  message "Cloud Configs Directory: ${cloudConfigsDir}"
fi

message ""
message "---------- Creating Cluster ----------"

# setup the urls to download the client and installer from when using curl or wget
baseURL=https://mirror.openshift.com/pub/openshift-v4/clients/ocp/${releaseVersion}
filenames=(client install)
binaries=(oc openshift-install)

# decide which program to use to download the files
# if one was not specified by the user
message "Checking available downloaders..."

if command -v curl 2>/dev/null && [ -z ${downloader} ] || [[ ${downloader} == "curl" ]]; then
  downloadCmd="curl -s -o"
fi
if command -v wget 2>/dev/null && [ -z ${downloader} ] || [[ ${downloader} == "wget" ]]; then
  downloadCmd="wget -q -O"
fi
if command -v oc 2>/dev/null && [ -z ${downloader} ] || [[ ${downloader} == "oc" ]]; then
  downloadCmd="oc"
fi
if [ -z "$downloadCmd" ]; then
  message "Unable to find oc, curl or wget to download the client and installer"
  exit 1
else
  message "Using downloader: ${downloadCmd}"
fi

# create a temporary directory to download the files to
rm -rf ${tmpdir}
mkdir -p ${tmpdir}
pushd ${tmpdir} > /dev/null

# download and extract the files
if [[ ${downloadCmd} == "oc" ]]; then
  message "Downloading openshift client and installer to ${tmpdir}"
  oc adm release extract --tools --to ${tmpdir} -a ${pullSecret} "${host}/${image}:${releaseVersion}"
else
  for i in "${filenames[@]}"
  do 
    message "Downloading openshift-${i}-${osType}-${releaseVersion}.tar.gz to ${tmpdir}"
    $downloadCmd openshift-${i}-${osType}-${releaseVersion}.tar.gz ${baseURL}/openshift-${i}-${osType}-${releaseVersion}.tar.gz
  done
fi

for i in "${filenames[@]}"
do 
  if [ ! -f openshift-${i}-${osType}-${releaseVersion}.tar.gz ]; then
      message "Failed to download openshift-${i}-${osType}-${releaseVersion}.tar.gz, exiting ..."
      exit 1
  fi
  message "Extracting openshift-${i}-${osType}-${releaseVersion}.tar.gz"
  tar -xzf openshift-${i}-${osType}-${releaseVersion}.tar.gz
done

# copy the binaries to ~/bin which should be in the users PATH
if [ ! -d ${HOME}/bin ]; then
  message "No ${HOME}/bin directory detected. Please create it and add it to your PATH."
fi
for i in "${binaries[@]}"
do
  message "Copying ${i} binary to ${HOME}/bin"
  cp -f ${i} ${HOME}/bin/
done

popd > /dev/null

if [ -f "${clusterDir}/metadata.json" ]; then
  message "Destroying previous cluster at ${clusterDir}"
  openshift-install destroy cluster --dir ${clusterDir}
  message "Removing ${clusterDir}"
  rm -rf ${clusterDir}
fi

message "Creating ${clusterDir}"
mkdir -p $clusterDir

pushd $clusterDir > /dev/null

if [ ! -z "$cloudConfig" ]; then
  message "Copying ${cloudConfig} from ${cloudConfigsDir}"
  cp ${cloudConfigsDir}/install-config-${cloudConfig}.yaml ${clusterDir}/install-config.yaml
else
  message "============ PULL SECRET ============"
  message " "
  cat $pullSecret | tr -d '\n' | tr -d ' '
  message "\n"
  message "====================================="
fi

message "Creating new cluster at ${releaseVersion}"

openshift-install create cluster --dir ${clusterDir}

message ""
message "Please run 'export KUBECONFIG=$clusterDir/auth/kubeconfig' to connect to your cluster."

popd > /dev/null
