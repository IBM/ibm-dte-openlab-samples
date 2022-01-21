#!/bin/bash

####
#
# This script will accept a e-mail address and IBMid unique ID for that user and
# add the user to the appropriate access group, create individual access policies,
# create Satellite config for the user, and create a version and subscription to 
# create OpenShift Namespaces/Projects for the user to use in the Satellite clusters
#
# Currently no error checking is done for any of the commands
#
####

####
#
# Global variables - these will change if Satellite environment is re-created
# Current TechZone - IBM Cloud Satellite shared environment
# These are current cluster and location IDs, cluster group names, and IAM group.
#
####

export AWS_CLUSTER_ID="c7k2vptw0u5mgaoug5dg"
export IBM_CLUSTER_ID="c7k3sfkw0rg6mjaceq7g"
export ALL_CLUSTERS="${AWS_CLUSTER_ID} ${IBM_CLUSTER_ID}"

export SAT_LOCATION="c7k1ppsw0375na2ceq5g"

export DEV_CLUSTER_GROUP="food-delivery-development-clusters"
export PROD_CLUSTER_GROUP="food-delivery-production-clusters"

export SAT_ACCESS_GROUP="satellite-user"




####
#
# functions
#
####


##### 
#
# set_access_groups()
# Add user and set access-group
# assuming TechZone will do the user invite/add so commented out next line
#
####
function set_access_groups() {

	##### 
	#
	# Add user and set access-group
	# assuming TechZone will do the user invite/add so commented out next line
	#
	####
	
	# ibmcloud account user-invite "${USERID}" --access-groups satellite-user 
	
	####
	#
	# add user the the access group
	# will they also do the access-group? or do we need to do it here
	#
	####
	
	echo Add ${USERID} to access group: ${SAT_ACCESS_GROUP} 
	ibmcloud iam access-group-user-add ${SAT_ACCESS_GROUP} ${USERID}

}

####
#
# set_access_policies()
# Set account policies for user
#
####
function set_access_policies() {


	for cluster in ${ALL_CLUSTERS}
	do
		
		# add policies for razeedeploy Namespace for each cluster so 
		# Sat config subscriptions will work
		echo Create Writer policy for ${USERID} in containers-kubernetes for namespace: razeedeploy  in cluster: ${cluster}
		
		ibmcloud iam user-policy-create ${USERID} --roles Writer --service-name "containers-kubernetes" --service-instance ${cluster} --attributes namespace=razeedeploy
	
		echo Create Administrator and Manager policies for ${USERID} in containers-kubernetes for namespace: ${USER_NAMESPACE} in cluster: ${cluster} 
		
		ibmcloud iam user-policy-create ${USERID} --roles Administrator,Manager --service-name "containers-kubernetes" --service-instance ${cluster} --attributes namespace=${USER_NAMESPACE}
	
	done
	
	echo Create Administrator,Manager, and Editor policies for ${USERID} in satellite configurations for namespace: ${USER_NAMESPACE}  
		
	ibmcloud iam user-policy-create ${USERID} --roles Editor,Manager,Administrator --service-name "satellite" --resource-type  "configuration" --resource ${USER_NAMESPACE}
	
	
}	

####
#
# creates_sat_resoruces()
# Create all the Satellite resources required
#	configuration
#	version to creates namespace in OpenShift Clusters
#	subscriptions to namespace verion for each cluster
#
####
function create_sat_resources() {
	####
	#
	# create Sat configuration
	# ibmcloud sat config create --name name [--data-location LOCATION] [-q]
	#
	####
	
	echo Create ${USER_NAMESPACE} satellite configuration
	
	ibmcloud sat config create --name ${USER_NAMESPACE}
	
	###
	#
	# create Namespace version
	# the CLI to create the version requires the yaml be in a file
	#    - create the file
	#    - create the version
	#    - remove the file
	# ibmcloud sat config version create --config CONFIG --file-format FORMAT --name NAME --read-config CONFIG [--description DESCRIPTION] [-q]
	#
	###
	
	echo Create version yaml file
	
	export VER_FILE_NAME="./tmpVersion-${USER_NAMESPACE}"
	cat > ${VER_FILE_NAME} <<-EOF
	apiVersion: project.openshift.io/v1
	kind: Project
	metadata:
	  name: ${USER_NAMESPACE}
	spec:
	  finalizers:
	  - kubernetes
	
	EOF
	
	echo create sat config version under ${USER_NAMESPACE} namespace using ${VER_FILE_NAME}
	
	ibmcloud sat config version create --config ${USER_NAMESPACE} -name ${USER_NAMESPACE} --description "autocreated namespace version" --file-format yaml --read-config ${VER_FILE_NAME}
	
	echo erase ${VER_FILE_NAME}
	
	rm ${VER_FILE_NAME}
	
	###
	#
	# create Namespace Subscription
	# ibmcloud sat subscription create --name NAME --group GROUP [--group GROUP] --config CONFIG --version VERSION [-q]
	# create subscription for all cluster gropus
	#
	###
	
	echo create sat subscriptions for all clusters
	
	ibmcloud sat subscription create --name  ${USER_NAMESPACE}-sub --group "${DEV_CLUSTER_GROUP}" --group "${PROD_CLUSTER_GROUP}" --config ${USER_NAMESPACE} --version ${USER_NAMESPACE}
	

}


####
#
# Main flow
#
####

####
#
# Currently expecting USERID (email address) and user's unique IBMid via command line
# we should do better command line processing here, but need to see what the terraform
# expectation is
#
####
export USERID=$1
export IBMUSERID=$2

# for testing
# andrew@jones-tx.com
# IBMid-2700039NFT
export USERID=andrew@jones-tx.com
export IBMUSERID=IBMid-2700039NFT

####
#
# using jq to parse json and get ibmUniqueID
#
# Note, the following doesn't need to be performed as the IBMUSER_ID (ibmUniqueId) 
# will be passed in by the TechZone reservation system 
# 
# doesn't work here unless user has already accepted invitation to the Cloud account
#
####


#IBMUSERID=`ibmcloud account users --output json | jq --arg USERID $USERID -c '[ .[] | select ( .userId | contains($USERID)) |  (.ibmUniqueId) ]' |cut -d '"' -f 2`

####
#
# Set namespace variable
# useing unique IBMid less the "IBMid-" prefix and adding "-ns"
# convert to all lower case as namespaces in OpenShift must be lower case
#
####
USER_NAMESPACE=`echo ${IBMUSERID} | cut -d '-' -f 2`"-ns"
USER_NAMESPACE=${USER_NAMESPACE,,}

# echo $USERID $IBMUSERID $USER_NAMESPACE

create_sat_resources
set_access_groups
set_access_policies



echo done

# remove user from access group
#ibmcloud iam access-group-user-remove GROUP_NAME USER_NAME
