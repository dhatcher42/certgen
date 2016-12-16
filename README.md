# certgen
This is a little hacky script I've done in order to easily generate certs for a MongoDB cluster.

# THIS IS NOT TO BE USED IN PRODUCTION

# Arguments

-c | --clients
Specify # of client certs
Default: 1

-m | --members
Specify # of member certs
Default: 3

-i | --intermediate
Specify # of intermediate certs
Default: 0

-p | --path
Specify where to save generated certs
Default: ~/scriptcerts

--nodelete
Specify to not delete pre-existing certs at path
Default: deletes certs
