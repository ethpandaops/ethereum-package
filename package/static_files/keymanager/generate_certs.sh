# To run this script, you need to have openssl installed on your machine
# This script generates a self-signed certificate and a private key, and then exports them to a PKCS12 keystore
# The keystore is encrypted with a password that is stored in a file called keymanager.txt
# The keystore is then saved to a file called validator_keystore.p12
# https://docs.teku.consensys.io/23.12.0/how-to/use-external-signer/manage-keys#support-multiple-domains-and-ips

openssl req -x509 -nodes -days 3650 -newkey rsa:2048 -config openssl.cnf | openssl pkcs12 -export -out validator_keystore.p12 -passout file:keymanager.txt
