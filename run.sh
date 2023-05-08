#!/bin/bash

# Function to show usage information

usage() {
	echo "Usage: $0 [--ownca CA_PATH]"
	echo " --ownca CA_PATH: Path to existing CA certificate and key files. Omit to generate a new CA."
	exit 1
}

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
	case "$1" in
	--ownca)
		OWNCA="yes"
		CA_PATH="$2"
		shift 2
		;;
	*)
		usage
		;;
	esac
done

# Check if required variables are set
REQUIRED_VARS=("COUNTRY" "STATE" "CITY" "ORG" "OU" "CN" "SERVER_ADMIN" "SERVER_NAME" "SERVER_ALIAS")
for VAR_NAME in "${REQUIRED_VARS[@]}"; do
	VAR_VALUE=$(eval echo \$$VAR_NAME)
	if [[ -z "${VAR_VALUE}" ]]; then
		echo "Error: The required environment variable '${VAR_NAME}' is not set."
		exit 1
	fi
done

# Update the package list
sudo apt-get update

# Install necessary packages
sudo apt-get install -y apache2 openssl php libapache2-mod-php php-sqlite3 sqlite3

# Enable necessary Apache modules
sudo a2enmod ssl
sudo a2enmod rewrite

# Create directories to store the root CA and server certificates
sudo mkdir -p /etc/apache2/ssl/rootCA
sudo mkdir -p /etc/apache2/ssl/server

# Create a self-signed root CA certificate if no existing CA is specified
if [ -z "$OWNCA" ]; then
	# Check if required variables for the root CA are set
	REQUIRED_VARS=("CA_COUNTRY" "CA_STATE" "CA_CITY" "CA_ORG" "CA_OU" "CA_CN")
	for VAR_NAME in "${REQUIRED_VARS[@]}"; do
		VAR_VALUE=$(eval echo \$$VAR_NAME)
		if [[ -z "${VAR_VALUE}" ]]; then
			echo "Error: The required environment variable '${VAR_NAME}' is not set."
			exit 1
		fi
	done

	# Generate a root CA with a 10-year validity
	sudo openssl genrsa -out /etc/apache2/ssl/rootCA/rootCA.key 4096
	sudo openssl req -x509 -new -nodes -key /etc/apache2/ssl/rootCA/rootCA.key -sha256 -days 3650 -out /etc/apache2/ssl/rootCA/rootCA.crt -subj "/C=${CA_COUNTRY}/ST=${CA_STATE}/L=${CA_CITY}/O=${CA_ORG}/OU=${CA_OU}/CN=${CA_CN}"
else
	# Check if script has permission to access the existing CA
	if [ ! -r "${CA_PATH}.crt" ] || [ ! -r "${CA_PATH}.key" ]; then
		echo "Script does not have permission to access the existing CA files or they do not exist."
		exit 1
	fi

	# Use the existing CA
	sudo cp "${CA_PATH}.crt" /etc/apache2/ssl/rootCA/rootCA.crt
	sudo cp "${CA_PATH}.key" /etc/apache2/ssl/rootCA/rootCA.key
fi

# Generate server key and CSR
sudo openssl genrsa -out /etc/apache2/ssl/server/server.key 2048
sudo openssl req -new -key /etc/apache2/ssl/server/server.key -out /etc/apache2/ssl/server/server.csr -subj "/C=${COUNTRY}/ST=${STATE}/L=${CITY}/O=${ORG}/OU=${OU}/CN=${CN}"

# Sign the server certificate with the root CA for 10 days
sudo openssl x509 -req -in /etc/apache2/ssl/server/server.csr -CA /etc/apache2/ssl/rootCA/rootCA.crt -CAkey /etc/apache2/ssl/rootCA/rootCA.key -CAcreateserial -out /etc/apache2/ssl/server/server.crt -days 10 -sha256
sudo bash -c 'cat /etc/apache2/ssl/server/server.crt /etc/apache2/ssl/rootCA/rootCA.crt > /etc/apache2/ssl/server/server-chain.crt'

# Source the Apache environment variables
source /etc/apache2/envvars

# Create a virtual host configuration file
sudo sh -c "echo '<VirtualHost *:80>
	ServerAdmin ${SERVER_ADMIN}
	ServerName ${SERVER_NAME}
	ServerAlias ${SERVER_ALIAS}
	DocumentRoot /var/www/html
	ErrorLog ${APACHE_LOG_DIR}/error.log
	CustomLog ${APACHE_LOG_DIR}/access.log combined
	RewriteEngine On
	RewriteCond %{HTTPS} off
	RewriteRule ^(.*)$ https://%{HTTP_HOST}%{REQUEST_URI} [L,R=301]
</VirtualHost>

<IfModule mod_ssl.c>
	<VirtualHost *:443>
		ServerAdmin ${SERVER_ADMIN}
		ServerName ${SERVER_NAME}
		ServerAlias ${SERVER_ALIAS}
		DocumentRoot /var/www/html
		ErrorLog ${APACHE_LOG_DIR}/error.log
		CustomLog ${APACHE_LOG_DIR}/ssl_access.log combined
		SSLEngine on
		SSLCertificateFile /etc/apache2/ssl/server/server-chain.crt
		SSLCertificateKeyFile /etc/apache2/ssl/server/server.key
		<FilesMatch \"\.(cgi|shtml|phtml|php)$\">
			SSLOptions +StdEnvVars
		</FilesMatch>
		<Directory /usr/lib/cgi-bin>
			SSLOptions +StdEnvVars
		</Directory>
		<Directory /var/www/html>
			Options Indexes FollowSymLinks MultiViews
			AllowOverride All
			Require all granted
		</Directory>
	</VirtualHost>
</IfModule>' > /etc/apache2/sites-available/000-custom-ssl.conf"

# Enable the custom virtual host
sudo a2ensite 000-custom-ssl

# Disable the default virtual host
sudo a2dissite 000-default

# Restart Apache to apply changes
sudo systemctl restart apache2

# Create a script to renew the server certificate
sudo sh -c "echo '#!/bin/bash

# Set the threshold (in days) for renewing the certificate
THRESHOLD=2

# Get the expiration date of the current certificate
EXPIRATION_DATE=\$(openssl x509 -in /etc/apache2/ssl/server/server.crt -enddate -noout | cut -d \"=\" -f 2)

# Convert the expiration date to the number of seconds since 1970-01-01 00:00:00 UTC
EXPIRATION_DATE_SEC=\$(date -d \"\${EXPIRATION_DATE}\" +%s)

# Get the current date and time in seconds
CURRENT_DATE_SEC=\$(date +%s)

# Calculate the time difference between the expiration date and the current date (in days)
TIME_DIFF_DAYS=\$(( (EXPIRATION_DATE_SEC - CURRENT_DATE_SEC) / 86400 ))

# Renew the certificate only if it is close to expiration
if [ \${TIME_DIFF_DAYS} -le \${THRESHOLD} ]; then
	# Generate server key and CSR
	sudo openssl genrsa -out /etc/apache2/ssl/server/server.key 2048
	sudo openssl req -new -key /etc/apache2/ssl/server/server.key -out /etc/apache2/ssl/server/server.csr -subj \"/C=${COUNTRY}/ST=${STATE}/L=${CITY}/O=${ORG}/OU=${OU}/CN=${CN}\"

	# Sign the server certificate with the root CA for 10 days
	sudo openssl x509 -req -in /etc/apache2/ssl/server/server.csr -CA /etc/apache2/ssl/rootCA/rootCA.crt -CAkey /etc/apache2/ssl/rootCA/rootCA.key -CAcreateserial -out /etc/apache2/ssl/server/server.crt -days 10 -sha256
	sudo bash -c '\''cat /etc/apache2/ssl/server/server.crt /etc/apache2/ssl/rootCA/rootCA.crt > /etc/apache2/ssl/server/server-chain.crt'\''

	# Restart Apache to apply changes
	sudo systemctl restart apache2
	echo \"Certificate has been renewed.\"
else
	echo \"Certificate is not close to expiration. No renewal is needed.\"
fi
' > /usr/local/bin/renew_cert.sh"


# Make the script executable
sudo chmod +x /usr/local/bin/renew_cert.sh

# Add a cron job to run the renewal script weekly
sudo bash -c '(crontab -l 2>/dev/null; echo "@weekly /usr/local/bin/renew_cert.sh") | crontab -'

echo "The root CA has been created or used, and the Apache certificate has been signed by the root CA for 10 days. A cron job has been added to automatically renew the certificate on a weekly basis."
