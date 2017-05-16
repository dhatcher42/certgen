#!/bin/bash

# set defaults

MEMBERS=1
CLIENTS=1
INTERMEDIATE=0
PTH=~/scriptcerts
HOSTNAME=`hostname -f`
VERBOSE=0
HELP=0
DELETE=1

# grab arguments

while [[ $# -gt 0 ]]
do
key="$1"

case $key in
	-h|--help)
	HELP=1
	shift
	;;
	-m|--members)
	MEMBERS="$2"
	shift # past argument
	;;
	-c|--clients)
	CLIENTS="$2"
	shift
	;;
	-i|--intermediate)
	INTERMEDIATE="$2"
	shift
	;;
	-p|--path)
	PTH="$2"
	shift
	;;
	--nodelete)
	DELETE=0
	shift
	;;
	-v|--verbose)
	VERBOSE=1
	shift
	;;
	*)
		# unknown options
	;;
esac
shift # past argument or value
done

if [[ -n $1 ]]
then
	echo "Last line of file specified as non-opt/last argument:"
	tail -1 $1
fi

# display help and exit
if [[ $HELP = 1 ]]
then
	echo "Usage: $0 [option...] {help|members|clients|intermediate|path|nodelete}"
	echo
	echo "	-h, --help 		Displays help and exits"
	echo "	-m, --members		Specify number of member certs"
	echo "	-c, --clients		Specify number of client certs"
	echo "	-i, --intermediate	Specify number of intermediate certs"
	echo "	-p, --path		Specify output path of generated certs"
	echo "	--nodelete		Do not delete existing certs in Path"
	echo "	-v, --verbose		Display all output"
	exit 0

else

# wipe all output unless verbose
if [[ $VERBOSE = 0 ]]
then
	exec &>/dev/null
fi

# delete old certs
if [[ $DELETE = 1 ]]
then
	rm -rf $PTH
fi

# create folder
mkdir $PTH 

# generate root cert

openssl req -x509 -newkey rsa:2048 -keyout $PTH/root.key -out $PTH/root.crt -nodes -subj "/C=US/ST=NewYork/L=NYC/O=MongoDB/OU=root/CN=root"
cat $PTH/root.crt > $PTH/ca.pem

# enter intermediate block

COUNTER=0
until [[ $COUNTER -eq $INTERMEDIATE ]]
do
	let COUNTER+=1

	# create extensions to sign as CA
	echo "basicConstraints = CA:TRUE" > $PTH/extensions.txt
	
	# generate cert
	openssl req -new -newkey rsa:2048 -keyout $PTH/intermediate$COUNTER.key -out $PTH/intermediate$COUNTER.csr -nodes -subj "/C=US/ST=NewYork/L=NYC/O=MongoDB/OU=intermediate/CN=$HOSTNAME"

	# if 
	if [[ $COUNTER -eq 1 ]]
	then
		# sign first intermediate against the root
		openssl x509 -req -extfile $PTH/extensions.txt -in $PTH/intermediate$COUNTER.csr -CA $PTH/root.crt -CAkey $PTH/root.key -CAcreateserial -out $PTH/intermediate$COUNTER.crt

	else
		# sign following intermediates against preceeding one
		openssl x509 -req -extfile $PTH/extensions.txt -in $PTH/intermediate$COUNTER.csr -CA $PTH/intermediate$[COUNTER-1].crt -CAkey $PTH/intermediate$[COUNTER-1].key -CAcreateserial -out $PTH/intermediate$COUNTER.crt
	fi

	# generate PEM
	cat $PTH/intermediate$COUNTER.crt $PTH/intermediate$COUNTER.key > $PTH/intermediate$COUNTER.pem 
	
	# add to CA bundle
	cat $PTH/ca.pem $PTH/intermediate$COUNTER.crt >> $PTH/ca.pem
done 


# enter member block

COUNTER=0
until [[ $COUNTER -eq $MEMBERS ]]
do
	let COUNTER+=1

	# generate cert
	openssl req -new -newkey rsa:2048 -keyout $PTH/member$COUNTER.key -out $PTH/member$COUNTER.csr -nodes -subj "/C=US/ST=NewYork/L=NYC/O=MongoDB/OU=member/CN=$HOSTNAME"

	# check whether there are intermediate certs
	# if not, sign against root
	if [[ $INTERMEDIATE -eq 0 ]]
	then
		# sign cert
		openssl x509 -req -in $PTH/member$COUNTER.csr -CA $PTH/root.crt -CAkey $PTH/root.key -CAcreateserial -out $PTH/member$COUNTER.crt

	# if yes, sign against last intermediate
	else
		# sign cert
		openssl x509 -req -in $PTH/member$COUNTER.csr -CA $PTH/intermediate$INTERMEDIATE.crt -CAkey $PTH/intermediate$INTERMEDIATE.key -CAcreateserial -out $PTH/member$COUNTER.crt
	fi

		# generate PEM
		cat $PTH/member$COUNTER.crt $PTH/member$COUNTER.key > $PTH/member$COUNTER.pem
done


# enter client block

COUNTER=0
until [[ $COUNTER -eq $CLIENTS ]]
do
	let COUNTER+=1

	# generate cert
	openssl req -new -newkey rsa:2048 -keyout $PTH/client$COUNTER.key -out $PTH/client$COUNTER.csr -nodes -subj "/C=US/ST=NewYork/L=NYC/O=MongoDB/OU=client/CN=$HOSTNAME"

	# check whether there are intermediate certs
	# if not, sign against root
	if [[ $INTERMEDIATE -eq 0 ]]
	then
		# sign cert
		openssl x509 -req -in $PTH/client$COUNTER.csr -CA $PTH/root.crt -CAkey $PTH/root.key -CAcreateserial -out $PTH/client$COUNTER.crt

	# if yes, sign against last intermediate
	else
		# sign cert
		openssl x509 -req -in $PTH/client$COUNTER.csr -CA $PTH/intermediate$INTERMEDIATE.crt -CAkey $PTH/intermediate$INTERMEDIATE.key -CAcreateserial -out $PTH/client$COUNTER.crt
	fi

	# generate PEM
	cat $PTH/client$COUNTER.crt $PTH/client$COUNTER.key > $PTH/client$COUNTER.pem 
done 

fi
