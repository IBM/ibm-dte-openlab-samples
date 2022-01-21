#!/bin/bash

####
#
# This script will accept a e-mail address and IBMid unique ID for that user and
# remove all automatically create resources and remove the users account
#
# Currently no error checking is done for any of the commands
#
####


####
#
# functions
#
####


##### 
#
# remove_user()
# Remove user from the account
#
####
function remove_user() {

	##### 
	#
	# remove user and set access-group
	# assuming TechZone will do the user invite/add so commented out next line
	#
	####
	
	# ibmcloud account user-remove USER_ID [-c, --account-id ACCOUNT_ID] [-f, --force] [-q, --quiet]
	
	echo Remove ${USERID} 
	ibmcloud account user-remove ${USERID} -f

}



####
#
# remove_sat_resources()
# Create all the Satellite resources required
#	remove subscription
#	remove version
#	remove configuration
#
####
function remove_sat_resources() {


	###
	#
	# remove Namespace Subscription
	#
	###
	
	echo remove sat subscriptions for all clusters
	
	ibmcloud sat subscription rm --subscription ${USER_NAMESPACE}-sub -f
	
	
	##
	## Do we need to sleep for some time til the clusters are 
	## actually updated (namespaces/projects deleted?
	##
	
	###
	#
	# remove Namespace version
	#
	###
	
	
	echo remove sat config version 
	ibmcloud sat config version rm --config ${USER_NAMESPACE} --version ${USER_NAMESPACE} -f
		
	####
	#
	# remove Sat configuration
	# 
	####
	
	echo Remove ${USER_NAMESPACE} satellite configuration
	
	ibmcloud sat config rm --config ${USER_NAMESPACE} -f
	

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

remove_sat_resources
remove_user



echo done

# remove user from access group
#ibmcloud iam access-group-user-remove GROUP_NAME USER_NAME
