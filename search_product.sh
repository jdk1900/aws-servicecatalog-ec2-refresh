#!/bin/bash
# parameter which holds the product name.
PRODUCT_NAME=$1

echo "Received Agent Name: '${PRODUCT_NAME}' "

if [ -z "$PRODUCT_NAME" ]; then 
    echo "Agent Name is empty.Exiting..."
    exit 1
fi

echo "Listing available products in AWS Service Catalog..."
aws servicecatalog search-products --region eu-west-1 --query "ProductViewSummaries[*].Name" --output json | jq -r '.[]'


echo "Searching for product: '${PRODUCT_NAME}'"
aws servicecatalog search-products --region eu-west-1 --output json > products.json
PRODUCT_ID=$(jq -r --arg name "$PRODUCT_NAME" '.ProductViewSummaries[] | select(.Name == $name) | .ProductId' products.json)  
echo "Search output: $PRODUCT_ID"


if [ -z "$PRODUCT_ID" ]; then
  echo "Product not found. Please check if the product name is correct."
  exit 1
else
  echo "##vso[task.setvariable variable=PRODUCT_ID]$PRODUCT_ID"
  echo "Agent found: $PRODUCT_ID"
fi
