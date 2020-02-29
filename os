#!/bin/sh

usage() {
cat <<EOF
  Usage: os [OPTIONS]...
  Download the OpenShift client and installer and launch a cluster.

  Optional Arguments:

 ============================ Cluster Functions ========================================

  --cloud-config     The name of the cloud configuration file to use. i.e. aws, gce, azure

  --cloud-config-dir Path to the folder containing the cloud configuration files
                     Defaults to ~/.openshift/configs

  --cluster-dir      Path to the folder to use for the files created by the installer.
                     Defaults to ~/openshift/cluster

  --downloader       Which program to use to download the client and installer.  i.e. oc, curl, wget
                     Defaults to oc

  --mirror-url       The url of the mirror that we should look for the client and installer on

  --os-type          Override the detected operating system. i.e. linux-gnu, darwin

  --pull-secret      Path to the file containing your pull secrets.  
                     Defaults to ~/.openshift/pull-secret.json

  --ssh-pubkey       Path to your ssh public key that should be used for
                     the cluster installation.
                     Defaults to ~/.ssh/id_rsa.pub                     

  --payload-host     Host to download the client/installer from when using the oc downloader.
                     Defaults to registry.svc.ci.openshift.org

  --payload-image    Image to download from the payloadhost when using the oc downloader.
                     Defaults to ocp/release

  --release-version  Version to use of the OpenShift client and installer.
                     Defaults to 4.2.9

  You can find a list of release versions and their supported downloader(s) below:

  Payload Host                                                           |  Downloader(s)
  ----------------------------------------------------------------------------------------
  registry.svc.ci.openshift.org                                          |  oc


  Mirror URL                                                             |  Downloader(s)
  ----------------------------------------------------------------------------------------
  https://mirror.openshift.com/pub/openshift-v4/clients/ocp              |  curl, wget
  https://mirror.openshift.com/pub/openshift-v4/clients/ocp-dev-preview  |  curl, wget


  ============================ Utility Functions ==================================

  --destroy-only     Destroy the current cluster and then exit.

  --tools-only       Download and install the OpenShift client and installer only
                     and don't remove a previous cluster or create a new one.

  --disable          cvo - Scales the Cluster Version Operator down to zero (0) so that
                           it won't overwrite your changes during development

  --enable           cvo - Scales the Cluster Version Operator up to one (1) which will
                           overwrite any development changes, so beware!  

  --update-image     cro - Tags docker.io/openshift/origin-cluster-image-registry-operator:latest to 
                           quay.io/<username>/origin-cluster-image-registry-operator:dev<random>
                           and then patches the deployment/cluster-image-registry-operator to use it  

  --quay-user         The username on quay.io that the image from --update-image should be pushed to.                                                 
   
  --show             pullsecret - Shows the pullsecret from ~/.openshift/pull-secret.json
                                  or a location specified with --pull-secret
                                  Removes newlines.                                  

  -h, --help         Display this help.
 
EOF
}

message () {
  printf "%s\n" "$1"
}

while [ "$1" != "" ]; do
    case $1 in
        --cloud-config )        shift
                                cloudConfig=$1
                                shift
                                ;;
        --cloud-config-dir )    shift
                                cloudConfigDir=$1
                                shift
                                ;;
        --cluster-dir )         shift
                                clusterDir=$1
                                shift
                                ;;
        --downloader )          shift
                                downloader=$1
                                shift
                                ;;
        --mirror-url )          shift
                                mirrorURL=$1
                                shift
                                ;;        
        --os-type )              shift
                                osType=$1
                                shift
                                ;;
        --payload-host )         shift
                                payloadHost=$1
                                shift
                                ;;  
        --payload-image )        shift
                                payloadImage=$1
                                shift
                                ;;  
        --pull-secret )         shift
                                pullSecret=$1
                                shift
                                ;;  
        --ssh-pubkey )          shift
                                sshPublicKey=$1
                                shift
                                ;;
        --release-version )     shift
                                releaseVersion=$1
                                shift
                                ;;   
        --tools-only )          shift
                                toolsOnly=true
                                ;;    
        --destroy-only )        shift
                                destroyOnly=true
                                ;; 
        --disable )             shift
                                disable=$1
                                shift
                                ;;   
        --enable )              shift
                                enable=$1
                                shift
                                ;;  
        --update-image )        shift
                                updateImage=$1
                                shift
                                ;;
        --quay-user )           shift
                                quayUser=$1
                                shift
                                ;;                                
       --show )                 shift
                                show=$1
                                shift
                                ;; 
        --dry-run )             shift
                                dryRun=true
                                ;;                                                                                  
        -h | --help )           usage
                                exit
                                ;;
        * )                     
                                usage
                                echo "Flag not found: ${1}"
                                exit 1
    esac
done



if [ ! -z "$dryRun" ]; then
  message "Dry run only!  No commands are being executed, only messages are displayed."
fi

# disable the Cluster Version Operator
if [ ! -z "$disable" ]; then
    if [ -z "$dryRun" ]; then
      if [[ "$disable" == "cvo" ]]; then
        message "Scaling the Cluster Version Operator to zero (0)"
        oc patch deployment/cluster-version-operator -n openshift-cluster-version -p='{"spec":{"replicas":0}}'
      fi
    fi
    exit 0
fi

# enable the Cluster Version Operator
if [ ! -z "$enable" ]; then
    if [ -z "$dryRun" ]; then
      if [[ "$enable" == "cvo" ]]; then
      message "Scaling the Cluster Version Operator to one (1)"
        oc patch deployment/cluster-version-operator -n openshift-cluster-version -p='{"spec":{"replicas":1}}'
      fi
    fi
    exit 0
fi

# detect the operating system and set the type for the client and installer
if [[ "$OSTYPE" == "linux-gnu" ]]; then
        osTypeDetected=linux
elif [[ "$OSTYPE" == "darwin"* ]]; then
        osTypeDetected=mac
else
  message "Unable to identify your operating system. Please specify using --os-type"
  exit 1
fi

# set sane defaults for any options that were not specified
cloudConfig=${cloudConfig:-""}
cloudConfigDir=${cloudConfigDir:-"${HOME}/.openshift/configs"}
clusterDir=${clusterDir:-"${HOME}/openshift/cluster"}
mirrorURL=${mirrorURL:-"https://mirror.openshift.com/pub/openshift-v4/clients/ocp/"}
pullSecret=${pullSecret:-"${HOME}/.openshift/pull-secret.json"}
sshPublicKey=${sshPublicKey:-"${HOME}/.ssh/id_rsa.pub"}
osType=${osType:=${osTypeDetected}}
releaseVersion=${releaseVersion:-"4.2.9"}
downloader=${downloader:-""}
host=${payloadHost:-"registry.svc.ci.openshift.org"}
image=${payloadImage:-"ocp/release"}
quayUser=${quayUser:-$USER}
tmpdir=/tmp/openshift-release

if [ ! -z "$show" ]; then
  if [[ "$show" == "pullsecret" ]]; then
    cat $pullSecret | tr -d '\n' | tr -d ' '
    echo ""
  fi
  exit 0
fi

if [ ! -z "$updateImage" ]; then
  message "Updating image for ${updateImage}"
  randomNumber=$RANDOM
  if [ -z "$dryRun" ]; then
    if [[ "$updateImage" == "cro" ]]; then
      croImage=quay.io/${quayUser}/origin-cluster-image-registry-operator:dev${randomNumber}
      docker tag docker.io/openshift/origin-cluster-image-registry-operator:latest ${croImage}
      docker push ${croImage}
      oc patch deployment/cluster-image-registry-operator -n openshift-image-registry -p='{"spec":{"template":{"spec":{"containers":[{"name":"cluster-image-registry-operator", "image":"'${croImage}'"}]}}}}'
    fi
  fi
  exit 0
fi

# show the user the config that we are going to use
message "---------- Using Configuration ----------"
message "Release Version:           ${releaseVersion}"
message "Operating System:          ${osType}"
message "Cluster Directory:         ${clusterDir}"
message "Pull Secret Location:      ${pullSecret}"
if [ ! -z "$cloudConfig" ]; then
  message "Cloud Config:            ${cloudConfig}"
  message "Cloud Config Directory:  ${cloudConfigDir}"
fi

message ""
message "---------- Downloading and Installing Client and Installer ----------"

# setup the urls to download the client and installer from when using curl or wget
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
if [ -z "$dryRun" ]; then
  rm -rf ${tmpdir}
  mkdir -p ${tmpdir}

  pushd ${tmpdir} > /dev/null
fi

# download and extract the files
if [[ ${downloadCmd} == "oc" ]]; then
  message "Downloading openshift client and installer to ${tmpdir}"
  if [ -z "$dryRun" ]; then
    oc adm release extract --tools --to ${tmpdir} -a ${pullSecret} "${host}/${image}:${releaseVersion}"
  fi
else
  for i in "${filenames[@]}"
  do 
    message "Downloading openshift-${i}-${osType}-${releaseVersion}.tar.gz to ${tmpdir}"
    if [ -z "$dryRun" ]; then
      $downloadCmd openshift-${i}-${osType}-${releaseVersion}.tar.gz ${mirrorURL}/${releaseVersion}/openshift-${i}-${osType}-${releaseVersion}.tar.gz
    fi
  done
fi

for i in "${filenames[@]}"
do 
  if [[ ! -f openshift-${i}-${osType}-${releaseVersion}.tar.gz  && -z "$dryRun" ]]; then
      message "Failed to download openshift-${i}-${osType}-${releaseVersion}.tar.gz, exiting ..."
      exit 1
  fi
  message "Extracting openshift-${i}-${osType}-${releaseVersion}.tar.gz"
  if [ -z "$dryRun" ]; then
    tar -xzf openshift-${i}-${osType}-${releaseVersion}.tar.gz
  fi
done

# copy the binaries to ~/bin which should be in the users PATH
if [ ! -d ${HOME}/bin ]; then
  message "No ${HOME}/bin directory detected. Please create it and add it to your PATH."
fi
for i in "${binaries[@]}"
do
  message "Copying ${i} binary to ${HOME}/bin"
  if [ -z "$dryRun" ]; then
    cp -f ${i} ${HOME}/bin/
  fi
done

if [ -z "$dryRun" ]; then
  popd > /dev/null
fi

if [ -z "${toolsOnly}" ]; then

  if [ -f "${clusterDir}/metadata.json" ]; then
    message "Destroying previous cluster at ${clusterDir}"
    if [ -z "$dryRun" ]; then
      openshift-install destroy cluster --dir ${clusterDir}
    fi
    message "Removing ${clusterDir}"
    if [ -z "$dryRun" ]; then
      rm -rf ${clusterDir}
    fi
  fi

  if [ ! -z "$destroyOnly" ]; then
    exit 0
  fi

  message "Creating ${clusterDir}"
  if [ -z "$dryRun" ]; then
    mkdir -p $clusterDir
  fi

  if [ -z "$dryRun" ]; then
    pushd $clusterDir > /dev/null
  fi

  if [ ! -z "${cloudConfig}" ]; then
    message "Copying ${cloudConfig} from ${cloudConfigDir}"
      PullSecret=$(cat $pullSecret | tr -d '\n' | tr -d ' ')
      SSHPublicKey=$(cat $sshPublicKey)
      if [ -z "$dryRun" ]; then
        eval "echo \"$(cat ${cloudConfigDir}/install-config-${cloudConfig}.yaml.tmpl)\"" > ${clusterDir}/install-config.yaml
      else
        message "---------- Rendered Cloud Config ----------"
        eval "echo \"$(cat ${cloudConfigDir}/install-config-${cloudConfig}.yaml.tmpl)\"" 
        message "-------------------------------------------"
      fi
  fi

  message "Creating new cluster at ${releaseVersion}"

  if [ -z "$dryRun" ]; then
    openshift-install create cluster --dir ${clusterDir}
  fi

  message ""
  message "Please run 'export KUBECONFIG=$clusterDir/auth/kubeconfig' to connect to your cluster."
  if [ -z "$dryRun" ]; then
    popd > /dev/null
  fi
fi
