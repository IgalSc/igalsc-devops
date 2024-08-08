#!/bin/bash

region="your-region"
profile="your-profile"
output_file="pending_certificates.txt"

# List certificates with status PENDING_VALIDATION
certs=$(aws acm list-certificates \
          --region $region \
          --profile $profile \
          --certificate-statuses PENDING_VALIDATION \
          --query 'CertificateSummaryList[].[CertificateArn]' \
          --output text)

# Redirect output to a file
echo "ARN,Domain Name,SANs" > $output_file

# Check if any certificates are found
if [ -z "$certs" ]; then
  echo "No pending certificates found."
else
  # Iterate over each certificate
  for arn in $certs; do
    # Get certificate details
    cert_details=$(aws acm describe-certificate \
                    --region $region \
                    --profile $profile \
                    --certificate-arn $arn)

    # Extract domain name
    domain_name=$(echo $cert_details | jq -r '.Certificate.DomainName')

    # Extract alternate domain names (SANs)
    sans=$(echo $cert_details | jq -r '.Certificate.SubjectAlternativeNames[]?' | paste -sd "," -)

    # Append to the output file
    echo "$arn,$domain_name,$sans" >> $output_file
  done
fi

echo "Pending certificates details saved to $output_file"