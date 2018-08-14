# OS

## A script to make OpenShift Origin development more pleasurable

## Introduction

This command line utility was created to make setting up and working
with a development environment for [OpenShift Origin](https://openshift.org) faster and simpler.

It's main goals are to:

 - Start up Origin with a sane set of defaults
 - Configure everything that you need to work on Origin including, but not limited to, the registry, the router, the web console, a basic set of templates, and a basic set of imagestreams
 - A single command to reset your current project
 - A single command to clean up your docker environment
 - Easier to remember commands to run tests
 - Ability to quickly login (via the CLI) as a regular user or the admin account
 - Easily copy the parts of Origin that have been split into separate repositories into their corresponding vendored directories in Origin.

All of these are pain points that I have personally encountered while working on the OpenShift Developer Experience Team at Red Hat.

I hope that others will find this script useful while working to make Origin the best PaaS that it can be.

### os
It is recommended that you symlink this file into your `~/bin` directory
so that you can run it without having to specify the path.  You will also
need to make sure that `~/bin` is on your `PATH`.

## Sample Workflow
This is a very basic sample of how you could use this script during
the development process.

```bash
// Let's create a new feature branch
$ git checkout -b my_new_feature

// Make sure that we have a clean slate to work with
$ os cleanall

// Write code for new feature
$ gvim .

// Now lets build Origin with our new code and start it up
// This will also create the master and node configuration files
// and set the domain to 127.0.0.1.nip.io for your applications.
// If you have made changes to code for the builder images or similar
// you should run os build-images first.
$ os start

// Now lets setup Origin
// This will install and configure the registry, router, web console,
// basic templates, imagestreams, and a user/project
$ os setup

// Now you can visit https://127.0.0.1 in your web browser and log into
// the web console, or use the CLI.
// The os login command will log you in as a user with the same name as
// the user on your workstation, and select a project with the same name.
$ os login

// If you want to login as the admin user
$ os login sys

// So we tested our code and need to make further changes.
// Let's shut down Origin, rebuild our code, and start Origin up again
$ os restart

// Ok, now we are ready to write some tests and run them locally.
// Depending on what kind of tests you are writing, you can run them
// using the following commands.

// Unit test named MyTestName in pkg/foo/bar
$ os test pkg/foo/bar MyTestName

// CLI Integration test for the new-app command
$ os testcmd newapp

// Integration test named FooBar
$ os testintegration FooBar

// End-To-End tests
$ os testendtoend

// Extended test named FooBar
$ os testextended FooBar

// Great! Everything is working and our tests are passing!
// Go ahead and commit your changes and push them to Github.

// We are all done for the day, lets stop Origin.
$ os stop

// If we want to, we can clean up after ourselves so we can
// start fresh in the morning!
$ os cleanall

```

## Usage

### build
Runs the `make build` command

Example:

```bash
$ os build
```

### build-images
Build images based on the currently checked out code and push them to the registry

```bash
$ os build-images <image>
```

### clean
Stops Origin and runs make clean

```bash
$ os clean
```

### cleanall
Runs all of the various clean commands

```bash
$ os cleanall
```

### cleanconfig
Removes the configuration files generated when starting Origin

```bash
$ os cleanconfig
```

### cleandocker
Removes all containers, volumes, and images from Docker and cleans up used space

```bash
$ os cleandocker
```

### completion
Runs the oc completion and oc adm completion commands and copies the files into your home directory.
You will still need to source these files in your `.bash_profile` or similar to get completion on the command line.

```bash
$ os completion
```

### copyapi
Copies the [api source code](https://github.com/openshift/api) into the correct vendor directory for testing.
The `api` source code must be checked out into your `$GOPATH` for this to work.

```bash
$ os copyapi
```

### copyclient-go
Copies the [client-go source code](https://github.com/openshift/client-go) into the correct vendor directory for testing.
The `client-go` source code must be checked out into your `$GOPATH` for this to work.

```bash
$ os copyclient-go
```

### copys2i
Copies the [source-to-image source code](https://github.com/openshift/source-to-image) into the correct vendor directory for testing.
The `source-to-image` source code must be checked out into your `$GOPATH` for this to work.

```bash
$ os copys2i
```

### gofmt
Runs the `gofmt` script on the Origin code, you will need to follow the
instructions displayed after running this command to fix the issues.

```bash
$ os gofmt
```

### reset
Deletes all resources for the currently logged in user effectively resetting your project.

```bash
$ os reset
```

### start | restart | reload
Start (or restart) Origin
Does a bunch of setup if you are starting with a clean environment.

```bash
$ os start
```

### stop
Stops Origin

```bash
$ os stop
```

### symlink-binaries
Symlinks the Origin binaries into `~/bin`.

```bash
$ os symlink-binaries
```

### test
Run Unit Tests, accepts package and test name as arguments.
[Official Documentation](https://github.com/openshift/origin/blob/master/HACKING.md#unit-tests)

```bash
$ os test pkg/foo/bar
$ os test pkg/foo/bar MyTestName
```

### testcmd
Run CLI Integration Tests, accepts a regex as an argument.

```bash
$ os testcmd newapp
```

### testintegration
Run the Integration Tests, accepts a regex as an argument.
[Official Documentation](https://github.com/openshift/origin/blob/master/HACKING.md#integration-tests)

```bash
$ os testintegration FooBar
```

### testendtoend
Run End-to-End (e2e) Tests, does not accept any arguments.
[Official Documentation](https://github.com/openshift/origin/blob/master/HACKING.md#end-to-end-e2e-and-extended-tests)

```bash
$ os testendtoend
```

### testextended
Run Extended Tests, accepts a regex that is passed to --ginkgo.focus
[Official Documentation](https://github.com/openshift/origin/blob/master/HACKING.md#end-to-end-e2e-and-extended-tests)

```bash
$ os testextended FooBar
```

### update
Runs the `make update` command.

```bash
$ os update
```

### verify
Runs the `make verify` command.

```bash
$ os verify
```
