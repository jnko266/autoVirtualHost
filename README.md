# Apache Auto Virtual Host Utility
This repository has a script in it that aims to automatically install and automatically configure LAMP stack on a Linux machine for local development

# How to use
1. Clone this repository
2. Export the following variables:
`export COUNTRY=GB STATE=England CITY=London ORG=Example OU=SW_ENG CN=example.com SERVER_ADMIN=hello@example.com`
3. Make the script executable:
`sudo chmod +x run.sh`
4. Run the script as root while preserving the environment variables:
`sudo -E ./run.sh`