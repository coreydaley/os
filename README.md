# OS

## A script to make bringing up an OpenShift cluster more pleasurable

## Introduction

This command line utility was created to make setting up and working
with a development environment for [OpenShift Origin](https://openshift.org) faster and simpler.

### Using Install Configs
You can create install configs using the `openshift-install create install-config` command  
and store them in `$HOME/.openshift/configs` and use them with this script using the `os --cloudconfig <type>` where `<type>` is one of aws, gce, or azure.  
You will need to name your install configs like `install-config-<type>.yaml` for this script to pick them up.

## os
It is recommended that you symlink this file into your `~/bin` directory
so that you can run it without having to specify the path.  You will also
need to make sure that `~/bin` is on your `PATH`.



## Usage
```
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

  --tools-only       Download and install the OpenShift client and installer only
                     and don't remove a previous cluster or create a new one.

  --disable-cvo      Scales the Cluster Version Operator down to zero (0) so that
                     it won't overwrite your changes during development

  --enable-cvo       Scales the Cluster Version Operator up to one (1) which will
                     overwrite any development changes, so beware!                                      

  -h, --help         Display this help.

```
