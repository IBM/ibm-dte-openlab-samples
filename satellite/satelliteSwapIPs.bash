#!/bin/bash
# 
# to get the lastest version of this script run the following command
# wget https://raw.githubusercontent.com/IBM/ibm-dte-openlab-samples/master/satellite/satelliteSwapIPs.bash
# chmod +x ./satelliteSwapIPS.bash
#



# move to home directory if not already there
cd $HOME

# some variables we will need
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
	echo ""
	aws configure
}

#---------------------------------------------------------------------------------------------
# add the public IPs for control plane to the satellite location DNS
# will exit if this fails
#---------------------------------------------------------------------------------------------
addPublicIPs4CP () {
	# add public IPs to Satellite Location configuration for control plane
	
	# build list string for command based upon arguements passed in
	params=""
	
	for i in "$@"
	do
		params="$params --ip $i "
	done
	echo "Updating location subdomain DNS records for control plane"
	ibmcloud sat location dns register --location $location $params


}

#---------------------------------------------------------------------------------------------
# add the public IPs for worker nodes to the OpenShift cluster Load Balancer and DNS
# currenlty assumes 3 - in clusterPIP[1-3] exported variables
# no error checking
#---------------------------------------------------------------------------------------------
addPublicIPs4Workers () {
	# add public IPs to Satellite Location configuration for worker nodes
		# build list string for command based upon arguements passed in
	
	echo "Updating cluster IPs for worker nodes"
	for i in "$@"
	do
		ibmcloud oc nlb-dns add --ip $i --cluster $clusterName --nlb-host $clusterHostname
		#echo ibmcloud oc nlb-dns add --ip $i --cluster $clusterName --nlb-host $clusterHostname
	done
	
# 		ibmcloud oc nlb-dns add --ip $clusterPIP1 --cluster $clusterName --nlb-host $clusterHostname
# 		ibmcloud oc nlb-dns add --ip $clusterPIP2 --cluster $clusterName --nlb-host $clusterHostname
# 		ibmcloud oc nlb-dns add --ip $clusterPIP3 --cluster $clusterName --nlb-host $clusterHostname
	
}

#---------------------------------------------------------------------------------------------
# remove the private IPs from the OpenShift cluster Load Balancer and DNS
# currently assumes 3 in clusterIP[1-3] exported variables
# no error checking
#---------------------------------------------------------------------------------------------
removePrivateIPs4Workers() {
	echo "Removing private IPs from NLB"
	for i in "$@"
	do
		# echo ibmcloud oc nlb-dns rm classic --ip $i --cluster $clusterName --nlb-host $clusterHostname
		ibmcloud oc nlb-dns rm classic --ip $i --cluster $clusterName --nlb-host $clusterHostname
	done
	# ibmcloud oc nlb-dns rm classic --ip $clusterIP1 --cluster $clusterName --nlb-host $clusterHostname
	# ibmcloud oc nlb-dns rm classic --ip $clusterIP2 --cluster $clusterName --nlb-host $clusterHostname
	# ibmcloud oc nlb-dns rm classic --ip $clusterIP3 --cluster $clusterName --nlb-host $clusterHostname
}

#---------------------------------------------------------------------------------------------
# cleanup temporary files
# 
#---------------------------------------------------------------------------------------------


cleanup() {
	rm $AWS_DESCRIBE_INSTANCES || echo "Unable to remove temporary file: $AWS_DESCRIBE_INSTANCES"
}

#---------------------------------------------------------------------------------------------
# Test an IP address for validity:
# Usage:
#      valid_ip IP_ADDRESS
#      if [[ $? -eq 0 ]]; then echo good; else echo bad; fi
#   OR
#      if valid_ip IP_ADDRESS; then echo good; else echo bad; fi
#---------------------------------------------------------------------------------------------
function valid_ip()
{
    local  ip=$1
    local  stat=1
# echo "valid_ip $ip"

    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        OIFS=$IFS
        IFS='.'
        ip=($ip)
        IFS=$OIFS
        [[ ${ip[0]} -le 255 && ${ip[1]} -le 255 \
            && ${ip[2]} -le 255 && ${ip[3]} -le 255 ]]
        stat=$?
    fi
# echo "valid_ip stat = $stat"
    return $stat
}

#---------------------------------------------------------------------------------------------
# prompt utility
# usage:
#    yesno "prompt with all spaces and punctiation (y|n)? "
#    returns 0 for Yes|Y|y
#    returns 1 for No|N|n
#---------------------------------------------------------------------------------------------

yesno() {

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
yesno "Do you want to download and install the AWS CLI (y|n)? " && installAWSCLI || echo "Skipping AWS CLI install."


#need to assume we installed it, will need to update if versions change
echo "Adding AWS CLI to PATH environment variable"
export PATH=$PATH:$BIN

# configure AWS CLI
echo
yesno "Do you want to configure the AWS CLI (y|n)? " && configureAWSCLI || echo "Skipping AWS CLI configuration."


### get Satellite Location name/ID
echo
echo "Enter your Satellite Location name or ID: "
read location
export location


# get all publice/private IPS for all ec2 instances in AWS and store in a temp file
# this file will be used multiple times and removed at the end
# make sure we only get ones associated with the location we care about
echo
echo "Retrieving public IPs for all AWS ec2 instances "
aws ec2 describe-instances|grep INSTANCES |grep $location > $AWS_DESCRIBE_INSTANCES



# get private IPs for control plane
locInfo=$(ibmcloud sat location dns ls --location $location -q|head -2 | tail -1)
set -a $locInfo
export locDNSName=$1
export locPrivateIPS=$2

echo
echo "found locDNSName = $locDNSName and locPrivateIPs = $locPrivateIPS"
echo

# get public IPs for control plane from AWS

echo "finding public IPs for all the private IPs for control plane"
echo

#stick local Private IPS in args, this should handle any number of IPs
IFS=","
set -- $locPrivateIPS
IFS=${origIFS}

export publicControlPlaneIPS=""
# echo commands = $@
for IP in "$@"
do
	# echo "looking for $IP"
	# echo
	## x=`awk {for(i=1;i<=NF;i++) {if(\$i==\"$IP\")print \$(i+1)}} $AWS_DESCRIBE_INSTANCES `
	
	x=$(awk "{for(i=1;i<NF;i++) {if(\$i==\"$IP\")print \$(i+1)}}" $AWS_DESCRIBE_INSTANCES)
	
	#echo x = $x
	publicControlPlaneIPS="$publicControlPlaneIPS $x"
	#echo $publicControlPlaneIPS
done
echo publicControlPlaneIPS = $publicControlPlaneIPS

for i in $publicControlPlaneIPS
do
	# echo validating IP - $i
	valid_ip $i || {
		echo "$i does not appear to be a valid IP address... you should probably skip the next step!"
	}
done

# set -- $publicControlPlaneIPS

echo
# add public IPs to DNS for Satellite Control Plane
yesno "Do you want to add public IPS to DNS for control plane (y|n)? " && addPublicIPs4CP $publicControlPlaneIPS || echo "Skipping add of Public IPs to DNS for control plane."

echo
echo "Enter your OpenShift cluster name or ID: "
read clusterName

# getting cluster hostname

echo
echo "Retrieving nlb-dns information for $clusterName"
clusterInfo=$(ibmcloud oc nlb-dns ls --cluster $clusterName -q) || {
        echo "ibmcloud oc nlb-dns failed.... aborting!"
        exit
}
# just want the single line with cluster info
clusterInfo=$(echo $clusterInfo |head -2 | tail -1 )

set -a $clusterInfo
clusterHostname=$1
clusterPrivateIPS=$2

echo "found clusterHostname = $clusterHostname and clusterPrivateIPS = $clusterPrivateIPS"



IFS=","
set -- $clusterPrivateIPS
IFS=${origIFS}

export publicWorkerNodeIPS=""
# echo commands = $@
for IP in "$@"
do
	x=$(awk "{for(i=1;i<NF;i++) {if(\$i==\"$IP\")print \$(i+1)}}" $AWS_DESCRIBE_INSTANCES)
	#echo x = $x
	publicWorkerNodeIPS="$publicWorkerNodeIPS $x"
	#echo $publicControlPlaneIPS
done
echo publicWorkerNodeIPS = $publicWorkerNodeIPS

for i in $publicWorkerNodeIPS
do
	# echo validating IP - $i
	valid_ip $i || {
		echo "$i does not appear to be a valid IP address... you should probably skip the next 2 steps!"
	}
done

echo

# add public IPs for worker nodes to OpenShift Cluster
yesno "Do you want to add public IPS to LB for worker nodes (y|n)? " && addPublicIPs4Workers $publicWorkerNodeIPS || echo "Skipping add of worker nodes IPS to LB."

IFS=","
set -- $clusterPrivateIPS
IFS=${origIFS}
echo
# configure remove Private IPs for worker nodes
yesno "Do you want to remove private IPs to LB for worker nodes (y|n)? " && removePrivateIPs4Workers $@ || echo "Skipping removal of private IPs of worker nodes IPS to LB."



echo
# cleanup
yesno "Do you want to remove temporary files (y|n)? " && cleanup || echo "Skipping removal of temporary files."
