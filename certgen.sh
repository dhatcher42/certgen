#!/bin/bash

# set defaults

MEMBERS=1
CLIENTS=1
INTERMEDIATE=0

# grab arguments

while [[ $# -gt 1 ]]
do
key="$1"

case $key in
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
	;;
	*)
		# unknown options
	;;
esac
shift # past argument or value
done

if [[ -n $1 ]]; then
	echo "Last line of file specified as non-opt/last argument:"
	tail -1 $1
fi

# delete old certs

rm -f /home/vagrant/scriptcerts/*

# generate root cert

openssl req -x509 -newkey rsa:2048 -keyout /home/vagrant/scriptcerts/root.key -out /home/vagrant/scriptcerts/root.crt -nodes -subj "/C=US/ST=NewYork/L=NYC/O=MongoDB/OU=root/CN=root"


# enter intermediate block

COUNTER=0
until [[ $COUNTER -eq $INTERMEDIATE ]]
do
	let COUNTER+=1

	# generate cert
	openssl req -new -newkey rsa:2048 -keyout /home/vagrant/scriptcerts/intermediate$COUNTER.key -out /home/vagrant/scriptcerts/intermediate$COUNTER.csr -nodes -subj "/C=US/ST=NewYork/L=NYC/O=MongoDB/OU=intermediate/CN=localhost.localdomain"

	# if 
	if [[ $COUNTER -eq 1 ]]
	then
		# sign first intermediate against the root
		openssl x509 -req -in /home/vagrant/scriptcerts/intermediate$COUNTER.csr -CA /home/vagrant/scriptcerts/root.crt -CAkey /home/vagrant/scriptcerts/root.key -CAcreateserial -out /home/vagrant/scriptcerts/intermediate$COUNTER.crt

	else
		# sign following intermediates against preceeding one
		openssl x509 -req -in /home/vagrant/scriptcerts/intermediate$COUNTER.csr -CA /home/vagrant/scriptcerts/intermediate$[COUNTER-1].crt -CAkey /home/vagrant/scriptcerts/intermediate$[COUNTER-1].key -CAcreateserial -out /home/vagrant/scriptcerts/intermediate$COUNTER.crt
	fi

	# generate PEM
	cat /home/vagrant/scriptcerts/intermediate$COUNTER.crt /home/vagrant/scriptcerts/intermediate$COUNTER.key > /home/vagrant/scriptcerts/intermediate$COUNTER.pem 
done 


# enter member block

COUNTER=0
until [[ $COUNTER -eq $MEMBERS ]]
do
	let COUNTER+=1

	# generate cert
	openssl req -new -newkey rsa:2048 -keyout /home/vagrant/scriptcerts/member$COUNTER.key -out /home/vagrant/scriptcerts/member$COUNTER.csr -nodes -subj "/C=US/ST=NewYork/L=NYC/O=MongoDB/OU=member/CN=localhost.localdomain"

	# check whether there are intermediate certs
	# if not, sign against root
	if [[ $INTERMEDIATE -eq 0 ]]
	then
		# sign cert
		openssl x509 -req -in /home/vagrant/scriptcerts/member$COUNTER.csr -CA /home/vagrant/scriptcerts/root.crt -CAkey /home/vagrant/scriptcerts/root.key -CAcreateserial -out /home/vagrant/scriptcerts/member$COUNTER.crt

	# if yes, sign against last intermediate
	else
		# sign cert
		openssl x509 -req -in /home/vagrant/scriptcerts/member$COUNTER.csr -CA /home/vagrant/scriptcerts/intermediate$INTERMEDIATE.crt -CAkey /home/vagrant/scriptcerts/intermediate$INTERMEDIATE.key -CAcreateserial -out /home/vagrant/scriptcerts/member$COUNTER.crt
	fi

		# generate PEM
		cat /home/vagrant/scriptcerts/member$COUNTER.crt /home/vagrant/scriptcerts/member$COUNTER.key > /home/vagrant/scriptcerts/member$COUNTER.pem
done


# enter client block

COUNTER=0
until [[ $COUNTER -eq $CLIENTS ]]
do
	let COUNTER+=1

	# generate cert
	openssl req -new -newkey rsa:2048 -keyout /home/vagrant/scriptcerts/client$COUNTER.key -out /home/vagrant/scriptcerts/client$COUNTER.csr -nodes -subj "/C=US/ST=NewYork/L=NYC/O=MongoDB/OU=client/CN=localhost.localdomain"

	# check whether there are intermediate certs
	# if not, sign against root
	if [[ $INTERMEDIATE -eq 0 ]]
	then
		# sign cert
		openssl x509 -req -in /home/vagrant/scriptcerts/client$COUNTER.csr -CA /home/vagrant/scriptcerts/root.crt -CAkey /home/vagrant/scriptcerts/root.key -CAcreateserial -out /home/vagrant/scriptcerts/client$COUNTER.crt

	# if yes, sign against last intermediate
	else
		# sign cert
		openssl x509 -req -in /home/vagrant/scriptcerts/client$COUNTER.csr -CA /home/vagrant/scriptcerts/intermediate$INTERMEDIATE.crt -CAkey /home/vagrant/scriptcerts/intermediate$INTERMEDIATE.key -CAcreateserial -out /home/vagrant/scriptcerts/client$COUNTER.crt
	fi

	# generate PEM
	cat /home/vagrant/scriptcerts/client$COUNTER.crt /home/vagrant/scriptcerts/client$COUNTER.key > /home/vagrant/scriptcerts/client$COUNTER.pem 
done 
