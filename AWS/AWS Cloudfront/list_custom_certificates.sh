#!/bin/bash

# Output CSV file
region="your-region"
profile="your-profile"
output_file="cloudfront_custom_certificates.csv"

# CSV Header
echo "DistributionId,DomainName,CertificateSource,CertificateId,AlternateDomainNames" > "$output_file"

# Get all CloudFront distributions with custom certificates
aws cloudfront list-distributions \
    --region "$region" \
    --profile "$profile" \
    --query "DistributionList.Items[?ViewerCertificate.CertificateSource!='cloudfront'].[Id, DomainName, ViewerCertificate.CertificateSource, ViewerCertificate.Certificate, Aliases.Items]" \
    --output json | \
jq -r '.[] | [
    .[0],                                           # DistributionId
    .[1],                                           # DomainName
    .[2],                                           # CertificateSource
    .[3],                                           # CertificateId
    (.[4] | join(";"))                              # AlternateDomainNames (Aliases)
] | @csv' >> "$output_file"

echo "Output written to $output_file"
