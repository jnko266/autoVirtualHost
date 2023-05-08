# Apache Auto Virtual Host Utility
This repository has a script in it that aims to automatically install and automatically configure LAMP stack on a Linux machine for local development

# How to use
1. Clone this repository
2. Export the following variables:
`export COUNTRY=GB CA_COUNTRY=US STATE=England CA_STATE=California CITY=London CA_CITY=SF ORG=Example CA_ORG=Example_US OU=SW_ENG CA_OU=SW_ENG2 CN=example.com CA_CN=test.com SERVER_ADMIN=hello@example.com SERVER_NAME="127.0.0.1" SERVER_ALIAS=localhost`
3. Make the script executable:
`sudo chmod +x run.sh`
4. Run the script as root while preserving the environment variables:
`sudo -E ./run.sh`