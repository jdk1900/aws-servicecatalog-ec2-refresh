#!/bin/bash
PRODUCT_ID="$PRODUCT_ID"
PARAMETERS_FILE="parameters.json"
PRODUCT_NAME="$1" #Get the product name
ASG_PREFIX="$2"   #Known prefix of the ASG name
CURRENT_ENVIRONMENT="$3" #Get the environment

echo Starting with $CURRENT_ENVIRONMENT environment...

# Funtion to perform the instance refresh
perform_instance_refresh() {

# Retrieve the full ASG name based on the prefix
ASG_NAME=$(aws autoscaling describe-auto-scaling-groups --query "AutoScalingGroups[?starts_with(AutoScalingGroupName, \`$ASG_PREFIX\`)].AutoScalingGroupName | [0]" --output text --region eu-west-1)


if [ "$ASG_NAME" == "" ]; then
  echo "No Auto Scaling Group found with prefix $ASG_PREFIX"
  exit 1
fi

# Start the instance refresh, also set the warm up to 1200 sec. It means that every EC2 instance will be replaced by a new one every 20 minutes.
  aws autoscaling start-instance-refresh \
  --auto-scaling-group-name "$ASG_NAME" \
  --preferences '{"InstanceWarmup": 1200, "MinHealthyPercentage": 67}' \
  --region eu-west-1
  echo "Instance refresh initiated for ASG: $ASG_NAME for environment $CURRENT_ENVIRONMENT "
}


# Ensure the parameters file exists
if [ ! -f "$PARAMETERS_FILE" ]; then
  echo "Error: Parameters file $PARAMETERS_FILE does not exist."
  exit 1
fi


# Read the parameters from the JSON file
PARAMS=$(cat "$PARAMETERS_FILE")


# Check if the product is already provisioned by it's ID.If yes, then a the PROVISIONED_PRODUCT_ID (associated with the product) will be listed in the Provisioned Products section.
echo "Check if the product is already provisioned..."
PROVISIONED_PRODUCT_ID=$(aws servicecatalog search-provisioned-products --query "ProvisionedProducts[?Name=='$PRODUCT_NAME'].Id" --output text --region eu-west-1)


# If the PROVISIONED_PRODUCT_ID is not listed in the "provisioned product" section, then proceed with provisioning the product
if [ -z "$PROVISIONED_PRODUCT_ID" ]; then


  echo "Product does not exist.Proceed with provisioning the product..."
  aws servicecatalog describe-product --id $PRODUCT_ID --region eu-west-1 --output json > product_details.json
  cat product_details.json
  PROVISIONING_ARTIFACT_ID=$(jq -r '[.ProvisioningArtifacts[]] | sort_by(.CreatedTime) | last(.[]).Id' product_details.json)
  echo "This is the Provisioning Artifact ID: $PROVISIONING_ARTIFACT_ID"


  aws servicecatalog provision-product \
  --product-id $PRODUCT_ID \
  --provisioning-artifact-id $PROVISIONING_ARTIFACT_ID \
  --provisioned-product-name $PRODUCT_NAME \
  --region eu-west-1 \
  --provisioning-parameters "$PARAMS"


  #sleep 600  # Sleep for 10 min to give time to AWS Service Catalog product to be provisioned.
  echo "Product provisioned successfully.EC2 instances will be refreshed one by one in ASG every 12 minutes.."
  exit 0


# else, If the PROVISIONED_PRODUCT_ID is present, then check the versions
else
echo "Product already exist, continue with checking the versions"


# Get the current provisioned artifact id from the list for comparison
aws servicecatalog describe-provisioned-product --id "$PROVISIONED_PRODUCT_ID" --region eu-west-1 --output json > current_provisioned_product.json
CURRENT_PROVISIONING_ARTIFACT_ID=$(jq -r '.ProvisionedProductDetail.ProvisioningArtifactId' current_provisioned_product.json)
echo "Current Provisioning Artifact ID: $CURRENT_PROVISIONING_ARTIFACT_ID"


# Get the newest artifact id for comparison
aws servicecatalog describe-product --id $PRODUCT_ID --region eu-west-1 --output json > product_details.json
PROVISIONING_ARTIFACT_ID=$(jq -r '[.ProvisioningArtifacts[]] | sort_by(.CreatedTime) | last(.[]).Id' product_details.json)
echo "This is the Provisioning Artifact ID: $PROVISIONING_ARTIFACT_ID"


if [ -z "$PROVISIONING_ARTIFACT_ID" ]; then
  echo "Failed to fetch the latest provisioning artifact ID. Exiting."
  exit 1
fi


echo "Latest provisioning artifact ID: $PROVISIONING_ARTIFACT_ID"
echo "Product name is: $PRODUCT_NAME"
echo $PARAMS
echo "The current version ID is $CURRENT_PROVISIONING_ARTIFACT_ID and the newest is $PROVISIONING_ARTIFACT_ID"


# Compare the two versions
if [ "$CURRENT_PROVISIONING_ARTIFACT_ID" == "$PROVISIONING_ARTIFACT_ID" ]; 
then
  echo "The provisioned product is already using the latest version. No action needed."
  exit 0
else
  echo "Updating the provisioned product to the latest version."
  aws servicecatalog update-provisioned-product \
  --product-id $PRODUCT_ID \
  --provisioned-product-id $PROVISIONED_PRODUCT_ID \
  --provisioning-artifact-id $PROVISIONING_ARTIFACT_ID \
  --region eu-west-1 \
  --provisioning-parameters "$PARAMS"


  sleep 600  # Sleep for 10 min to give time to AWS Service Catalog product to be updated.
  echo "Product provisioned successfully.EC2 instances will be refreshed one by one in ASG every 12 minutes.."
  # Call the function to refresh the instances after updating
  perform_instance_refresh


fi
fi
