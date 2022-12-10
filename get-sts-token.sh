#!/bin/bash
# Make sure you have IAM non-temporary keys that have permission to get AWS  profile in aws cli.
# To configure such profile you can use: $ aws configure
# To configure a MFA device on IAM, refer to: https://docs.aws.amazon.com/IAM/latest/UserGuide/id_credentials_mfa_enable_virtual.html#enable-virt-mfa-for-iam-user
#
# More info about temorary credentials, refer to:https://docs.aws.amazon.com/IAM/latest/UserGuide/id_credentials_temp_use-resources.html
#
# Add this bash script to your $PATH to run system wide
# Example: if script is located on /usr/local/bin/, make export PATH=/usr/local/bin:$PATH

unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN

MFA_VIRTUAL_DEVICE="arn:aws:iam::199859470528:mfa/ischneider"
echo "Enter MFA Code:"
read MFA_TOKEN

eval $(aws sts get-session-token --serial-number ${MFA_VIRTUAL_DEVICE} --token-code ${MFA_TOKEN} | jq -r '.Credentials | "export AWS_ACCESS_KEY_ID=\(.AccessKeyId)\nexport AWS_SECRET_ACCESS_KEY=\(.SecretAccessKey)\nexport AWS_SESSION_TOKEN=\(.SessionToken)\n"')
