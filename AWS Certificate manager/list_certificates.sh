# This script will populate a txt file 
# with all the AWS Certificate Manager certificates, 
# their Domain names and SANs

#!/bin/bash

region="your-region"
profile="your-profile"
output_file="certificates.txt"

# List certificates
certs=$(aws acm list-certificates --region $region --profile $profile --query 'CertificateSummaryList[].[CertificateArn]' --output text)

# Redirect output to a file
echo "ARN,Domain Name,SANs" > $output_file

# Iterate over each certificate
for arn in $certs; do
  # Get certificate details
  cert_details=$(aws acm describe-certificate --region $region --profile $profile --certificate-arn $arn)

  # Extract domain name
  domain_name=$(echo $cert_details | jq -r '.Certificate.DomainName')

  # Extract alternate domain names (SANs)
  sans=$(echo $cert_details | jq -r '.Certificate.SubjectAlternativeNames[]?' | paste -sd "," -)

  # Append to the output file
  echo "$arn,$domain_name,$sans" >> $output_file
done

echo "Certificates details saved to $output_file"
