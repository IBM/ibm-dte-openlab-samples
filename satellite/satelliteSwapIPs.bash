#!/bin/bash
# wget https://raw.githubusercontent.com/IBM/ibm-dte-openlab-samples/master/satellite/satelliteSwapIPs.bash

# move to home directory if not already there
cd $HOME

export origIFS=$IFS
export AWSREGION="us-east-2"
export AWS_INSTALL="$HOME/awsinstall"        # directory for binary
export BIN="$HOME/bin"
export AWS_DESCRIBE_INSTANCES="$HOME/awsInstances.txt"

#---------------------------------------------------------------------------------------------
# install AWS Command Line Interfaces 
# will download, unzip, and install in to 
# local directory since we don't have root access in Cloud Terminal
#---------------------------------------------------------------------------------------------
installAWSCLI () {
	echo "Downloading AWS CLI"
	curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" -q
	echo "Unzipping AWS CLI"
	unzip -qq awscliv2.zip || {
		echo "Unable to unzip AWS command line utility archive. Aborting."
		exit 1
	}
	echo "Creating directories for AWS CLI install and binaries"
	mkdir $AWS_INSTALL || {
		echo "Unable to create AWS install directory: $AWS_INSTALL.  Aborting."
		exit 1
	}
	mkdir $BIN || {
		echo "unable to create binary direcotry: $BIN. Aborting."
		exit 1
	}
	echo "Installing AWS CLI"
	./aws/install -i $AWS_INSTALL -b $BIN
}

#---------------------------------------------------------------------------------------------
# run AWS configure to set Access ID and secret access key
# user will need to provide those values
#---------------------------------------------------------------------------------------------
configureAWSCLI () {
	echo ""
	echo "In the next step, you will need your AWS access key ID and AWS secret access key."
	echo "When prompted for region enter $AWSREGION or the appropriate region for your Satellite Location."
	echo "When prompted for output format enter \"text\"."
	echo "Running aws configure"
	aws configure
}

#---------------------------------------------------------------------------------------------
# add the public IPs for control plane to the satellite location DNS
# will exit if this fails
#---------------------------------------------------------------------------------------------
addPublicIPs4CP () {
	# add public IPs to Satellite Location configuration for control plane

	echo "Updating location subdomain DNS records for control plane"
	ibmcloud sat location dns register --location $location --ip $PIP1 --ip $PIP2 --ip $PIP3  || {
		echo "Error trying to set DNS IPS for contol plane"
		exit 1
	}
}

#---------------------------------------------------------------------------------------------
# add the public IPs for worker nodes to the OpenShift cluster Load Balancer and DNS
# currenlty assumes 3 - in clusterPIP[1-3] exported variables
# no error checking
#---------------------------------------------------------------------------------------------
addPublicIPs4Workers () {
	# add public IPs to Satellite Location configuration for worker nodes
	
	echo "Updating cluster IPs for worker nodes"
	ibmcloud oc nlb-dns add --ip $clusterPIP1 --cluster $clusterName --nlb-host $clusterHostname
	ibmcloud oc nlb-dns add --ip $clusterPIP2 --cluster $clusterName --nlb-host $clusterHostname
	ibmcloud oc nlb-dns add --ip $clusterPIP3 --cluster $clusterName --nlb-host $clusterHostname

}

#---------------------------------------------------------------------------------------------
# remove the private IPs from the OpenShift cluster Load Balancer and DNS
# currently assumes 3 in clusterIP[1-3] exported variables
# no error checking
#---------------------------------------------------------------------------------------------
removePrivateIPs4Workers() {
	echo "Removing private IPs from NLB"
	ibmcloud oc nlb-dns rm classic --ip $clusterIP1 --cluster $clusterName --nlb-host $clusterHostname
	ibmcloud oc nlb-dns rm classic --ip $clusterIP2 --cluster $clusterName --nlb-host $clusterHostname
	ibmcloud oc nlb-dns rm classic --ip $clusterIP3 --cluster $clusterName --nlb-host $clusterHostname
}

#---------------------------------------------------------------------------------------------
# prompt utility
# usage:
#    yesno "prompt with all spaces and punctiation (y|n)? "
#    returns 0 for Yes|Y|y
#    returns 1 for No|N|n
#---------------------------------------------------------------------------------------------

function yesno {

	read -p "$@" -n 1 -r
	echo
	
	if [[ $REPLY =~ ^[Yy]$ ]]
	then
		return 0 
	elif [[ $REPLY =~ ^[Nn]$ ]]
	then
		return 1
	else
		echo "Invalid response, please try again."
		# echo "\$@ = $@"
		# making recursive call and returning valid answer back... eventually
		yesno "$@"
		return $?
	fi
}

#---------------------------------------------------------------------------------------------
# Main flow
# currently prompting before we take any action
#---------------------------------------------------------------------------------------------


# install AWS CLI
yesno "Do you want to install the AWS CLI (y|n)? " && installAWSCLI || echo "Skipping AWS CLI install."

# 
# echo "Do you want to install the AWS CLI (y|n)?"; read ans
# if [[ "$ans" == "y" || "$ans" == "Y" ]]
# then
# 	installAWSCLI
# else
# 	echo "Skipping AWS CLI install"
# fi

#need to assume we installed it, will need to update if versions change
echo "Adding AWS CLI to PATH environment variable"
export PATH=$PATH:$BIN

# configure AWS CLI
yesno "Do you want to configure the AWS CLI (y|n)? " && configureAWSCLI || echo "Skipping AWS CLI configuration."

# echo "Do you want to configure the AWS CLI (y|n)?"; read ans
# if [[ "$ans" == "y" || "$ans" == "Y" ]]
# then
# 	configureAWSCLI
# else
# 	echo "Skipping AWS CLI configuration"
# fi

# get all publice/private IPS for all ec2 instances in AWS and store in a temp file
# this file will be used multiple times and removed at the end
echo "Retrieving public IPs for all AWS ec2 instances "
aws ec2 describe-instances|grep INSTANCES > $AWS_DESCRIBE_INSTANCES


### get Satellite Location name/ID
echo
echo "Enter your Satellite Location name or ID: "
read location

export location

# get private IPs for control plane
locInfo=$(ibmcloud sat location dns ls --location $location -q|head -2 | tail -1)
set -a $locInfo
export locDNSName=$1
export locPrivateIPS=$2

echo "found locDNSName = $locDNSName and locPrivateIPs = $locPrivateIPS"


#### old way
# get the 3 IPS....
#IFS=","
#set -a $locPrivateIPS
#export IP1=$1
#export IP2=$2
#export IP3=$3
#IFS=${origIFS}
#####




# get public IPs for control plane from AWS

echo "finding public IPs for all the private IPs for control plane"

#stick local Private IPS in args
IFS=","
set -- $locPrivateIPS
IFS=${origIFS}

export publicControlPlaneIPS=""
echo commands = $@
for IP in "$@"
do
   echo "looking for $IP"
   x=`awk {for(i=1;i<=NF;i++) {if(\$i==\"$IP\")print \$(i+1)}} $AWS_DESCRIBE_INSTANCES `
   echo x = $x
   publicControlPlaneIPS="$publicControlPlateIPS $x"
   echo $publicControlPlaneIPS
done
echo $publicControlPlaneIPS
exit


# PublicIPs=$(aws ec2 describe-instances |grep INSTANCES | awk "{for(i=1;i<=NF;i++) {if(\$i==\"$IP1\")print \$(i+1); if(\$i==\"$IP2\") print \$(i+1); if(\$i==\"$IP3\") print \$(i+1)}}")


# get all the public IPs for control plane from temp file


echo PublicIPs = $PublicIPs
set -a $PublicIPs

export PIP1=$1
export PIP2=$2
export PIP3=$3

echo "PIP1 = $PIP1"
echo "PIP2 = $PIP2"
echo "PIP3 = $PIP3"

# add public IPs to DNS for Satellite Control Plane
yesno "Do you want to add public IPS to DNS for control plane (y|n)? " && addPublicIPs4CP || echo "Skipping add of Public IPs to DNS for control plane."

# echo "Do you want to add public IPS to DNS for control plane (y|n)?"; read ans
# if [[ "$ans" == "y" || "$ans" == "Y" ]]
# then
# 	addPublicIPs4CP
# else
# 	echo "Skipping adding Public IPs to DNS for control plane."
# fi




echo "Enter your OpenShift cluster name or ID: "
read clusterName

# getting cluster hostname


clusterInfo=$(ibmcloud oc nlb-dns ls --cluster $clusterName -q|head -2 | tail -1)
set -a $clusterInfo
clusterHostname=$1
clusterPrivateIPS=$2

echo "found clusterHostname = $clusterHostname and clusterPrivateIPS = $clusterPrivateIPS"


IFS=","
set -a $clusterPrivateIPS
export clusterIP1=$1
export clusterIP2=$2
export clusterIP3=$3
echo "cluster private IPS = $1 $2 $3 "
IFS=${origIFS}

#aws ec2 describe-instances |grep INSTANCES | awk "{for(i=1;i<=NF;i++) {if(\$i==\"$clusterIP1\")print \$i \" \" \$(i+1); if(\$i==\"$clusterIP2\") print \$i \" \" \$(i+1); if(\$i==\"$clusterIP3\") print \$i \" \" \$(i+1)}}"
clusterPublicIPs=$(aws ec2 describe-instances |grep INSTANCES | awk "{for(i=1;i<=NF;i++) {if(\$i==\"$clusterIP1\")print \$(i+1); if(\$i==\"$clusterIP2\") print \$(i+1); if(\$i==\"$clusterIP3\") print \$(i+1)}}")


echo "Cluster PublicIPs = $clusterPublicIPs"
set -a $clusterPublicIPs

export clusterPIP1=$1
export clusterPIP2=$2
export clusterPIP3=$3

echo "cluster PIP1 = $clusterPIP1"
echo "cluster PIP2 = $clusterPIP2"
echo "cluster PIP3 = $clusterPIP3"

# add public IPs for worker nodes to OpenShift Cluster
yesno "Do you want to add public IPS to LB for worker nodes (y|n)? " && addPublicIPs4Workers || echo "Skipping add of worker nodes IPS to LB."


# echo "Do you want to add public IPS to LB for worker nodes (y|n)?"; read ans
# if [[ "$ans" == "y" || "$ans" == "Y" ]]
# then
# 	addPublicIPs4Workers
# else
# 	echo "Skipping adding worker nodes IPS to LB"
# fi

# configure remove Private IPs for worker nodes
yesno "Do you want to remove private IPs to LB for worker nodes (y|n)? " && removePrivateIPs4Workers || echo "Skipping removing private IPs of worker nodes IPS to LB."


# echo "Do you want to remove private IPs to LB for worker nodes (y|n)?"; read ans
# if [[ "$ans" == "y" || "$ans" == "Y" ]]
# then
# 	removePrivateIPs4Workers
# else
# 	echo "Skipping adding worker nodes IPS to LB"
# fi
