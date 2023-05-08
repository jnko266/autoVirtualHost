# Apache Auto Virtual Host Utility
This repository has a script in it that aims to automatically install all necessary dependencies, create a self-signed certificate (and CA for signing this certificate), create an Apache virtual host and configure it to use the certificate, and finally, add a record to crontab to renew the certificate @weekly months.  
The script can also use an existing CA if they are provided using the `--ownca` flag (which is supposed to be the path to the CA certificate and key in PEM format).
# How to use
1. Clone this repository
2. Export Certificate Authority environment variables:  
```
export CA_COUNTRY=US \
CA_STATE=California \
CA_CITY="San Francisco" \
CA_ORG="Your Organisation Name" \
CA_OU=main \
CA_CN="CA Common Name"
```
3. Export the server certificate environment variables:
```
export COUNTRY=GB \
STATE=England \
CITY=London \
ORG="Your Organisation Name" \
OU="Department Name" \
CN="Local Certificate Common Name"
```
4. Export the server information environment variables:
```
export SERVER_ADMIN="hello@example.com" \
SERVER_NAME="127.0.0.1" \
SERVER_ALIAS=localhost
```
3. Make the script executable:
`sudo chmod +x run.sh`
4. Run the script as root while preserving the environment variables:
`sudo -E ./run.sh`