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

  --tools-only       Download and install the OpenShift client and installer only
                     and don't remove a previous cluster or create a new one.

  -h, --help         Display this help.
```
