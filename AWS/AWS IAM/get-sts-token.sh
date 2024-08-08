#!/bin/bash
# Make sure you have IAM non-temporary keys that have permission to get AWS  profile in aws cli.
# To configure such profile you can use: $ aws configure
# To configure a MFA device on IAM, refer to:
#https://docs.aws.amazon.com/IAM/latest/UserGuide/id_credentials_mfa_enable_virtual.html#enable-virt-mfa-for-iam-user
#
# More info about temorary credentials, refer to:https://docs.aws.amazon.com/IAM/latest/UserGuide/id_credentials_temp_use-resources.html
#
# Add this bash script to your $PATH to run system wide
# Example: if script is located on /usr/local/bin/, make export PATH=/usr/local/bin:$PATH

unset AWS_ACCESS_KEY_ID
unset AWS_SECRET_ACCESS_KEY
unset AWS_SESSION_TOKEN

MFA_VIRTUAL_DEVICE="arn:aws:iam::199859470528:mfa/ischneider"
echo "Enter MFA Code:"
read MFA_TOKEN

echo "Configuring credentials with token $MFA_TOKEN"
unset CREDJSON
export CREDJSON="$(aws sts get-session-token --serial-number $MFA_VIRTUAL_DEVICE --token-code $MFA_TOKEN)"
echo $CREDJSON
ACCESSKEY="$(echo $CREDJSON | jq '.Credentials.AccessKeyId' | sed 's/"//g')"
SECRETKEY="$(echo $CREDJSON | jq '.Credentials.SecretAccessKey' | sed 's/"//g')"
SESSIONTOKEN="$(echo $CREDJSON | jq '.Credentials.SessionToken' | sed 's/"//g')"

export AWS_ACCESS_KEY_ID=ACCESSKEY
export AWS_SECRET_ACCESS_KEY=SECRETKEY
export AWS_SESSION_TOKEN=SESSIONTOKEN

#####################################################
