#!/bin/bash

origIFS=$IFS
echo "Downloading AWS CLI"
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
echo "Unzipping AWS CLI"
unzip awscliv2.zip
echo "Creating directory for AWS CLI binaries"
mkdir awsbin
echo "Installing AWS CLI"
./aws/install -i awsbin
echo "Adding AWS CLI to PATH environment variable"
export PATH=$PATH:$HOME/awsbin/v2/2.3.2/bin
echo "In the next step, you will need your AWS access key ID and AWS secret access key."
echo "When prompted for region enter \"us-east-2\""
echo "When prompted for output format enter \"text\""
echo "Running aws configure"
aws configure


echo "Press enter to continue or Ctrl C to end?"
read x

echo "Enter your Satellite Location name or ID: "
read location
# get private IPs for control plane
locInfo=$(ibmcloud sat location dns ls --location $location -q|head -2 | tail -1)
set -a $locInfo
locDNSName=$1
locPrivateIPS=$2

echo "found locDNSName = $locDNSName and locPrivateIPs = $locPrivateIPS"
IFS=","
set -a $locPrivateIPS
export IP1=$1
export IP2=$2
export IP3=$3
echo "1 = $1 2 = $2 3 = $3"
IFS=${origIFS}

echo "Press enter to continue to get was private IPs or Ctrl C to end?"
read x

# get public IPs for control plane from AWS
echo "Retrieving public IPs for control plate private IPS"

#aws ec2 describe-instances |grep INSTANCES | awk "{for(i=1;i<=NF;i++) {if(\$i==\"$IP1\")print \$i \" \" \$(i+1); if(\$i==\"$IP2\") print \$i \" \" \$(i+1); if(\$i==\"$IP3\") print \$i \" \" \$(i+1)}}"
PublicIPs=$(aws ec2 describe-instances |grep INSTANCES | awk "{for(i=1;i<=NF;i++) {if(\$i==\"$IP1\")print \$(i+1); if(\$i==\"$IP2\") print \$(i+1); if(\$i==\"$IP3\") print \$(i+1)}}")

echo PublicIPs = $PublicIPs
set -a $PublicIPs

export PIP1=$1
export PIP2=$2
export PIP3=$3

echo "PIP1 = $PIP1"
echo "PIP2 = $PIP2"
echo "PIP3 = $PIP3"

echo "Press enter to add private IPs to DNS for control plane or Ctrl C to end?"
read x

# add public IPs to Satellite Location configuration for control plane

echo "Updating location subdomain DNS records for control plane"
ibmcloud sat location dns register --location $location --ip $PIP1 --ip $PIP2 --ip $PIP3

echo "Press enter to get cluster worker nodes Ctrl C to end?"
read x

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

echo "Press enter to get cluster worker node public IPs or Ctrl C to end?"
read x

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


echo "Press enter to get add public IPs to LB or Ctrl C to end?"
read x

# add public IPs to Satellite Location configuration for control plane

echo "Updating cluster IPs for worker nodes"
ibmcloud oc nlb-dns add --ip $clusterPIP1 --cluster $clusterName --nlb-host $clusterHostname
ibmcloud oc nlb-dns add --ip $clusterPIP2 --cluster $clusterName --nlb-host $clusterHostname
ibmcloud oc nlb-dns add --ip $clusterPIP3 --cluster $clusterName --nlb-host $clusterHostname

echo "Press enter to get remove private IPs to LB or Ctrl C to end?"
read x

echo "Removing private IPs from NLB"
ibmcloud oc nlb-dns rm classic --ip $clusterIP1 --cluster $clusterName --nlb-host $clusterHostname
ibmcloud oc nlb-dns rm classic --ip $clusterIP2 --cluster $clusterName --nlb-host $clusterHostname
ibmcloud oc nlb-dns rm classic --ip $clusterIP3 --cluster $clusterName --nlb-host $clusterHostname
