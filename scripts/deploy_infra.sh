#!/bin/bash

###
### deploy_datalake_infra — connects to AWS and creates the data lake infrastructure like buckets, security groups, etc. related to datalake
###
### Usage:
###   deploy_datalake_infra.sh

# https://vaneyckt.io/posts/safer_bash_scripts_with_set_euxo_pipefail/
set -euxo pipefail

readonly SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
readonly PROJECT_DIR="${SCRIPT_DIR%/*}"

## Script Defaults

## Expected Environment Variables and overrides
readonly PRODUCT="aws-home-learning"
readonly TEAM="team-crp"

export AWS_DEFAULT_REGION="us-east-1"

# Enivornment Context
ACCOUNT_ALIAS="$(aws iam list-account-aliases --query "AccountAliases" --output text)"
ENV="dev"
TENANT="aws-home"
ACCOUNT_ID=$(aws sts get-caller-identity --query ['Account'] --output text)

VPC_ID=$(aws ec2 describe-vpcs | jq -r '.Vpcs[] | select(.InstanceTenancy == "default").VpcId')


SUBNETS_ID1=$(aws ec2 describe-subnets | jq -r '.Subnets[] | select(.AvailabilityZoneId == "use1-az1").SubnetId')
SUBNETS_ID2=$(aws ec2 describe-subnets | jq -r '.Subnets[] | select(.AvailabilityZoneId == "use1-az2").SubnetId')
SUBNETS_ID3=$(aws ec2 describe-subnets | jq -r '.Subnets[] | select(.AvailabilityZoneId == "use1-az3").SubnetId')

SECURITY_GROUP_ID=$(aws ec2 describe-security-groups | jq -r '.SecurityGroups[] | select(.GroupName == "default").GroupId')

# ADMIN_ROLE_ARN=$


# # Generic Resource tag variables
# case $ENV in
#   (dev | int | cons)
#     ENV_TAG="stagging"
#     DP_PERSONAL_TAG="false"
#     ;;
#   (prod)
#     ENV_TAG="production"
#     DP_PERSONAL_TAG="true"
#     ;;
#   (*)
#     printf >&2 '%s\n' "Unsupported type: $ENV"
#     exit 1
# esac
# # Tag for mps:application:name
# APP_NAME_TAG="vci-data-lake-infra"
# # Tag for mps:data-privacy:classification
# DP_CLASS_TAG="vwfs:data-classification:confidential"
# # Tag for mps:data-privacy:personal-data
# # DP_PERSONAL_TAG="true"
# # Tag for mps:data-privacy:credit-card-data
# DP_CC_TAG="false"
# # Tag for mps:business-continuity:backup-plan
# BUSS_CONT_TAG="mps-monthly-backup-plan"



echo "Variables defined in script"
echo "  SCRIPT_DIR - $SCRIPT_DIR"
echo "  PROJECT_DIR - $PROJECT_DIR"
echo "  PRODUCT - $PRODUCT"
echo "  TEAM - $TEAM"
echo "  AWS_DEFAULT_REGION - $AWS_DEFAULT_REGION"
echo "  ACCOUNT_ALIAS - $ACCOUNT_ALIAS"
echo "  ENV - $ENV"
echo "  TENANT - $TENANT"
echo "  ACCOUNT_ID - $ACCOUNT_ID"
# echo "  SUBNETS - $SUBNETS"
# echo "  SUBNETS - $DB1_SUBNET"

echo "  VPC_ID - $VPC_ID"
echo "  SUBNETS_ID1 - $SUBNETS_ID1"
echo "  SUBNETS_ID2 - $SUBNETS_ID2"
echo "  SUBNETS_ID3 - $SUBNETS_ID3"
echo "  SECURITY_GROUP_ID - $SECURITY_GROUP_ID"


echo " Software versions:"
echo "  - aws [$(aws --version)]"
echo "  - sam [$(sam --version)]"
echo "  - jq [$(jq --version)]"



# ###
# # Function Declarions
# ###

function deploy_kms_key()
{

    STACK_NAME=$PRODUCT"-kms-key"
    echo "Stack Name: $STACK_NAME is being deployed"
    BASE_DIR="$(pwd)/templates/kms"
    echo "Base Directory: $BASE_DIR"

    aws cloudformation deploy \
        --template-file $BASE_DIR/kms-template.yaml \
        --stack-name $STACK_NAME \
        --no-fail-on-empty-changeset

}

function deploy_buckets()
{
    STACK_NAME=$PRODUCT"-buckets"
    echo "Stack Name: $STACK_NAME is being deployed"
    BASE_DIR="$(pwd)/templates/s3"
    echo "Base Directory: $BASE_DIR"
    

    aws cloudformation deploy \
        --template-file $BASE_DIR/s3-template.yaml \
        --stack-name $STACK_NAME \
        --no-fail-on-empty-changeset

}

function deploy_msk()
{
    STACK_NAME=$PRODUCT"-msk"
    echo "Stack Name: $STACK_NAME is being deployed"
    BASE_DIR="$(pwd)/templates/msk"
    echo "Base Directory: $BASE_DIR"

    ## Get KMS_KEY_ID
    KMS_KEY_ID=$(aws cloudformation describe-stacks --stack-name $PRODUCT"-kms-key" | jq -r '.Stacks[0].Outputs[] | select(.OutputKey == "KeyArn").OutputValue')
    echo "KMS_KEY_ID: $KMS_KEY_ID"

    ## Get S3 Bucket Name
    S3_BUCKET_NAME=$(aws cloudformation describe-stacks --stack-name $PRODUCT"-buckets" | jq -r '.Stacks[0].Outputs[] | select(.OutputKey == "S3BucketName").OutputValue')
    echo "S3_BUCKET_NAME: $S3_BUCKET_NAME"
    

    aws cloudformation deploy \
        --template-file $BASE_DIR/msk-template-sl.yaml \
        --stack-name $STACK_NAME \
        --parameter-overrides \
        KmsKeyId=$KMS_KEY_ID \
        SubnetId1=$SUBNETS_ID1 \
        SubnetId2=$SUBNETS_ID2 \
        SubnetId3=$SUBNETS_ID3 \
        S3BucketName=$S3_BUCKET_NAME \
        SecurityGroupId=$SECURITY_GROUP_ID \
        --no-fail-on-empty-changeset

    # aws cloudformation deploy \
    #     --template-file $BASE_DIR/msk-template-prov.yaml \
    #     --stack-name $STACK_NAME \
    #     --parameter-overrides \
    #     KmsKeyId=$KMS_KEY_ID \
    #     SubnetId1=$SUBNETS_ID1 \
    #     SubnetId2=$SUBNETS_ID2 \
    #     SubnetId3=$SUBNETS_ID3 \
    #     S3BucketName=$S3_BUCKET_NAME \
    #     SecurityGroupId=$SECURITY_GROUP_ID \
    #     --no-fail-on-empty-changeset


}

function main() {

  deploy_kms_key
  deploy_buckets
  deploy_msk

  echo "Infrastructure completed successfully!"
}

###
# Script Execution
###

main "$@"

# function get_stage(){
#   local accountAlias=$(aws iam list-account-aliases --query "AccountAliases" --output text)
#   local stage=$(echo $accountAlias | awk -F "-" '{print $NF}')
#   echo "${stage}"
# }



# function deploy_iam {
#   pwd
#   aws cloudformation deploy \
#     --capabilities CAPABILITY_IAM \
#     --capabilities CAPABILITY_NAMED_IAM \
#     --template-file templates/iam/iam-stack.yaml \
#     --stack-name vci-data-pipeline-iam-stack \
#     --parameter-overrides \
#         Env=$ENV \
#         AWSTenant=$TENANT \
#         DsnaAccountId=$DSNA_ACCT_ID \
#         CrossAccountDsnaRole=$CROSS_ACCT_DSNA_ROLE \
#         TeamTag=$TEAM_TAG \
#     --no-fail-on-empty-changeset

#   aws cloudformation describe-stack-events --stack-name vci-data-pipeline-iam-stack

# }

# function deploy_sg {
#   pwd
#   aws cloudformation deploy \
#     --template-file templates/security/security-groups.yaml \
#     --stack-name vci-data-pipeline-sg-stack \
#     --parameter-overrides \
#         Env=$ENV \
#         AWSTenant=$TENANT \
#         TeamTag=$TEAM_TAG \
#         VpcId=$VPC_ID \
#     --no-fail-on-empty-changeset

#     aws cloudformation describe-stack-events --stack-name vci-data-pipeline-sg-stack

# }

# function deploy_s3_endpoint {

# echo "Deploying S3 Endpoint"
# BASE_DIR="$(pwd)/templates/security"
# echo "Base Directory: $BASE_DIR"
# aws cloudformation deploy \
#     --template-file $BASE_DIR/s3-vpc-endpoint.yaml \
#     --stack-name vci-data-pipeline-ep-stack \
#     --parameter-overrides \
#         Env=$ENV \
#         AWSTenant=$TENANT \
#         TeamTag=$TEAM_TAG \
#         VpcId=$VPC_ID \
#     --no-fail-on-empty-changeset
# }

# function deploy_glue_connection {
# echo "Deploying glue connections"
# BASE_DIR="$(pwd)/templates/security"
# echo "Base Directory: $BASE_DIR"
# aws cloudformation deploy \
#     --template-file $BASE_DIR/glue-connections.yaml \
#     --stack-name vci-data-pipeline-glue-connections-stack \
#     --parameter-overrides \
#         Env=$ENV \
#         AWSTenant=$TENANT \
#         TeamTag=$TEAM_TAG \
#         VpcId=$VPC_ID \
#         SubnetId=$DB1_SUBNET \
#     --no-fail-on-empty-changeset
# }


# function deploy_sns {

#   aws cloudformation deploy \
#     --template-file templates/sns/vci_datapipeline_sns_topic.yaml \
#     --stack-name vci-data-pipeline-sns-stack \
#     --parameter-overrides \
#         Env=$ENV \
#         AWSTenant=$TENANT \
#         TeamTag=$TEAM_TAG \
#         SNSTopicName="vci_datapipeline_sns_topic" \
#         SubscriptionEmail="chirag.patel@vwcredit.com" \
#         DsnaAccountId=$DSNA_ACCT_ID \
#         MPSEnvTag=$ENV_TAG \
#         MPSStageTag=$ENV \
#         MPSAppNameTag=$APP_NAME_TAG \
#         MPSDPClassTag=$DP_CLASS_TAG \
#         MPSDPPersonalTag=$DP_PERSONAL_TAG \
#         MPSDPCredCardTag=$DP_CC_TAG \
#         MPSBusContBPTag=$BUSS_CONT_TAG \
#     --no-fail-on-empty-changeset

#   aws cloudformation describe-stack-events --stack-name vci-data-pipeline-sns-stack

# }
# function deploy_bucket {
#   pwd

#   aws cloudformation deploy \
#     --template-file templates/s3/s3-buckets.yaml \
#     --stack-name vci-data-pipeline-s3-stack \
#     --parameter-overrides \
#         AWSTenant=$TENANT \
#         DsnaAccountId=$DSNA_ACCT_ID \
#         CrossAccountDsnaRole=$CROSS_ACCT_DSNA_ROLE \
#         Env=$ENV \
#         TeamTag=$TEAM_TAG \
#         MPSEnvTag=$ENV_TAG \
#         MPSStageTag=$ENV \
#         MPSAppNameTag=$APP_NAME_TAG \
#         MPSDPClassTag=$DP_CLASS_TAG \
#         MPSDPPersonalTag=$DP_PERSONAL_TAG \
#         MPSDPCredCardTag=$DP_CC_TAG \
#         MPSBusContBPTag=$BUSS_CONT_TAG \
#     --no-fail-on-empty-changeset

#   aws cloudformation describe-stack-events --stack-name vci-data-pipeline-s3-stack
#   aws s3api put-object --bucket=${CONFIG_BUCKET} --key=glue/timebound/timebound.csv --body=templates/glue/timebound/timebound.csv --server-side-encryption=aws:kms
#   aws s3api put-object --bucket=${CONFIG_BUCKET} --key=lib/spark-avro_2.11-2.4.4.jar --body=templates/glue/lib/spark-avro_2.11-2.4.4.jar --server-side-encryption=aws:kms
#   aws s3api put-object --bucket=${STAGE_BUCKET} --key=axway/dummy_file.txt --body=templates/s3/dummy_file.txt --server-side-encryption=aws:kms
# }


# function deply_glue {

#   aws s3api put-object --bucket=${ARTIFACTS_BUCKET} --body=templates/glue/glue-load-raw-to-curated.py --key=glue/glue-load-raw-to-curated.py --server-side-encryption=aws:kms
#   aws s3api put-object --bucket=${ARTIFACTS_BUCKET} --body=templates/glue/glue-load-curated-to-transformed-copied.py --key=glue/glue-load-curated-to-transformed-copied.py --server-side-encryption=aws:kms
#   aws s3api put-object --bucket=${ARTIFACTS_BUCKET} --body=templates/glue/glue-load-curated-to-transformed.py --key=glue/glue-load-curated-to-transformed.py --server-side-encryption=aws:kms
#   aws s3api put-object --bucket=${ARTIFACTS_BUCKET} --body=templates/glue/glue-load-raw-to-curated-full-delta.py --key=glue/glue-load-raw-to-curated-full-delta.py --server-side-encryption=aws:kms
#   aws s3api put-object --bucket=${ARTIFACTS_BUCKET} --body=templates/glue/glue-load-raw-to-curated-type2-dim.py --key=glue/glue-load-raw-to-curated-type2-dim.py --server-side-encryption=aws:kms
#   aws s3api put-object --bucket=${ARTIFACTS_BUCKET} --body=templates/glue/glue-transform-curated-to-transformed-auction_fact.py --key=glue/glue-transform-curated-to-transformed-auction_fact.py --server-side-encryption=aws:kms

#   aws cloudformation deploy \
#       --template-file templates/glue/glue.yaml\
#       --stack-name vci-data-ingestion-pipeline-glue-jobs-stack \
#       --parameter-overrides \
#           TeamTag=$TEAM_TAG \
#           AWSTenant=$TENANT \
#           Env=$ENV \
#           ArtifactsBucket=$ARTIFACTS_BUCKET \
#       --no-fail-on-empty-changeset

#   echo "Glue completed successfully!"

#   #aws cloudformation describe-stack-events --stack-name vci-data-ingestion-pipeline-glue-jobs-stack
# }

# function deploy_lakeformation {
#     echo "Deploying lakeformation stack"
#     BASE_DIR="$(pwd)/templates/lakeformation"
#     aws cloudformation deploy \
#         --capabilities CAPABILITY_IAM \
#         --template-file $BASE_DIR/lake-formation-permissions.yaml \
#         --stack-name vci-sfn-lake-formation-permissions-stack \
#         --parameter-overrides \
#             TeamTag=$TEAM_TAG \
#             Env=$ENV \
#         --no-fail-on-empty-changeset
# }




# function deploy_lambda_role {
#   pwd
#   aws cloudformation deploy \
#     --capabilities CAPABILITY_IAM \
#     --capabilities CAPABILITY_NAMED_IAM \
#     --template-file templates/iam/lambda-role.yaml \
#     --stack-name vci-data-pipeline-lambda-iam-stack \
#     --parameter-overrides \
#         Env=$ENV \
#         AWSTenant=$TENANT \
#         DsnaAccountId=$DSNA_ACCT_ID \
#         CrossAccountDsnaRole=$CROSS_ACCT_DSNA_ROLE \
#         TeamTag=$TEAM_TAG \
#     --no-fail-on-empty-changeset

#   aws cloudformation describe-stack-events --stack-name vci-data-pipeline-lambda-iam-stack

# }


# function deploy_api_stream {

#   sam build \
#       --template-file templates/sam/api-stream-s3-ingestion/template.yaml \
#       --build-dir templates/sam/api-stream-s3-ingestion/.aws-sam && \
#   sam package \
#       --template-file templates/sam/api-stream-s3-ingestion/.aws-sam/template.yaml \
#       --s3-bucket $ARTIFACTS_BUCKET \
#       --s3-prefix $SAM_PREFIX \
#       --output-template-file templates/sam/api-stream-s3-ingestion/output.yaml && \

#   sam deploy --template-file /tmp/build/46a9765d/source/templates/sam/api-stream-s3-ingestion/output.yaml  \
#       --stack-name vci-data-pipeline-api-streaming-pipeline-stack \
#       --capabilities CAPABILITY_IAM \
#       --parameter-overrides \
#           AWSTenant=$TENANT \
#           Env=$ENV \
#       --no-fail-on-empty-changeset   

#   echo "api stream SFn completed successfully!"
#   #aws cloudformation describe-stack-events --stack-name vci-data-pipeline-lambda-stack
# }

# function deploy_lambda {

#   sam build \
#       --template-file templates/sam/lambda-axway-file-stage/template.yaml \
#       --build-dir templates/sam/lambda-axway-file-stage/.aws-sam && \
#   sam package \
#       --template-file templates/sam/lambda-axway-file-stage/.aws-sam/template.yaml \
#       --s3-bucket $ARTIFACTS_BUCKET \
#       --s3-prefix $SAM_PREFIX \
#       --output-template-file templates/sam/lambda-axway-file-stage/output.yaml && \

#   sam deploy --template-file /tmp/build/46a9765d/source/templates/sam/lambda-axway-file-stage/output.yaml  \
#       --stack-name vci-data-pipeline-lambda-stack-axway \
#       --parameter-overrides \
#           AWSTenant=$TENANT \
#           Env=$ENV \
#       --no-fail-on-empty-changeset

  
# #   create folder for s3 config
#   aws s3api put-object --bucket ${CONFIG_BUCKET}  --key config/lake_config/  --server-side-encryption=aws:kms
#   sam build \
#       --template-file templates/sam/lambda-lake-prebuild-conf/template.yaml \
#       --build-dir templates/sam/lambda-lake-prebuild-conf/.aws-sam && \
#   sam package \
#       --template-file templates/sam/lambda-lake-prebuild-conf/.aws-sam/template.yaml \
#       --s3-bucket $ARTIFACTS_BUCKET \
#       --s3-prefix $SAM_PREFIX \
#       --output-template-file templates/sam/lambda-lake-prebuild-conf/output.yaml && \

#   sam deploy --template-file /tmp/build/46a9765d/source/templates/sam/lambda-lake-prebuild-conf/output.yaml  \
#       --stack-name vci-data-pipeline-lambda-stack-prebuild \
#       --parameter-overrides \
#           AWSTenant=$TENANT \
#           Env=$ENV \
#       --no-fail-on-empty-changeset    


#   sam build \
#       --template-file templates/sam/lambda-run-crawler/template.yaml \
#       --build-dir templates/sam/lambda-run-crawler/.aws-sam && \
#   sam package \
#       --template-file templates/sam/lambda-run-crawler/.aws-sam/template.yaml \
#       --s3-bucket $ARTIFACTS_BUCKET \
#       --s3-prefix $SAM_PREFIX \
#       --output-template-file templates/sam/lambda-run-crawler/output.yaml && \

#   sam deploy --template-file /tmp/build/46a9765d/source/templates/sam/lambda-run-crawler/output.yaml  \
#       --stack-name vci-data-pipeline-lambda-stack-crawler \
#       --parameter-overrides \
#           AWSTenant=$TENANT \
#           Env=$ENV \
#           Subnets=$SUBNETS \
#       --no-fail-on-empty-changeset 


#   sam build \
#       --template-file templates/sam/lambda-mwaa-api-call/template.yaml \
#       --build-dir templates/sam/lambda-mwaa-api-call/.aws-sam && \
#   sam package \
#       --template-file templates/sam/lambda-mwaa-api-call/.aws-sam/template.yaml \
#       --s3-bucket $ARTIFACTS_BUCKET \
#       --s3-prefix $SAM_PREFIX \
#       --output-template-file templates/sam/lambda-mwaa-api-call/output.yaml && \

#   sam deploy --template-file /tmp/build/46a9765d/source/templates/sam/lambda-mwaa-api-call/output.yaml  \
#       --stack-name vci-data-pipeline-lambda-stack-mwaa \
#       --parameter-overrides \
#           AWSTenant=$TENANT \
#           Env=$ENV \
#           Subnets=$SUBNETS \
#       --no-fail-on-empty-changeset     

# #   sam build \
# #       --template-file templates/sam/lambda-trigger-sfn-data-pipeline/template.yaml \
# #       --build-dir templates/sam/lambda-trigger-sfn-data-pipeline/.aws-sam && \
# #   sam package \
# #       --template-file templates/sam/lambda-trigger-sfn-data-pipeline/.aws-sam/template.yaml \
# #       --s3-bucket $ARTIFACTS_BUCKET \
# #       --s3-prefix $SAM_PREFIX \
# #       --output-template-file templates/sam/lambda-trigger-sfn-data-pipeline/output.yaml && \

# #   sam deploy --template-file /tmp/build/46a9765d/source/templates/sam/lambda-trigger-sfn-data-pipeline/output.yaml  \
# #       --stack-name vci-data-pipeline-lambda-stack-sfn-datapipeline \
# #       --parameter-overrides \
# #           AWSTenant=$TENANT \
# #           Subnets=$SUBNETS \
# #           Env=$ENV \
# #       --no-fail-on-empty-changeset     
        

# #   echo "Lambda SFn completed successfully!"
#   #aws cloudformation describe-stack-events --stack-name vci-data-pipeline-lambda-stack
# }

# function deploy_glue_crawler {

#   sam build \
#       --template-file templates/sam/lambda-trigger-glue-crawler/template.yaml \
#       --build-dir templates/sam/lambda-trigger-glue-crawler/.aws-sam && \
#   sam package \
#       --template-file templates/sam/lambda-trigger-glue-crawler/.aws-sam/template.yaml \
#       --s3-bucket $ARTIFACTS_BUCKET \
#       --s3-prefix $SAM_PREFIX \
#       --output-template-file templates/sam/lambda-trigger-glue-crawler/output.yaml && \

#   # cd  /tmp/build/46a9765d/source/templates/sam/
#   #ls -la
#   sam deploy \
#       --template-file /tmp/build/46a9765d/source/templates/sam/lambda-trigger-glue-crawler/output.yaml \
#       --stack-name vci-glue-crawler-trigger-lambda-stack \
#       --parameter-overrides \
#           TeamTag=$TEAM_TAG \
#           AWSTenant=$TENANT \
#           Env=$ENV \
#           Subnets=$SUBNETS \
#           crawleriamrole='glue-service-role' \
#       --no-fail-on-empty-changeset

#   echo "Glue Crawler completed successfully!"
# }

# function deploy_cloudtrail {

#   aws cloudformation deploy \
#       --template-file templates/cloudtrail/cloudtrail.yaml \
#       --stack-name vci-data-pipeline-cloudtrail-stack \
#       --parameter-overrides \
#           Env=$ENV \
#           AWSTenant=$TENANT \
#           DsnaAccountId=$DSNA_ACCT_ID \
#           CrossAccountDsnaRole=$CROSS_ACCT_DSNA_ROLE \
#           TeamTag=$TEAM_TAG \
#           MPSEnvTag=$ENV_TAG \
#           MPSStageTag=$ENV \
#           MPSAppNameTag=$APP_NAME_TAG \
#           MPSDPClassTag=$DP_CLASS_TAG \
#           MPSDPPersonalTag=$DP_PERSONAL_TAG \
#           MPSDPCredCardTag=$DP_CC_TAG \
#           MPSBusContBPTag=$BUSS_CONT_TAG \
#       --no-fail-on-empty-changeset

#   echo "CloudTrail completed successfully!"
# }

# function sfn_data_ingestion_pipeline {
#   echo "Deploying sfn for Data Ingestion pipeline Started"
#   BASE_DIR="$(pwd)/templates/sam/sfn_data_ingestion_pipeline"
#   echo "Base Directory: $BASE_DIR"
#   sam build \
#       --template-file $BASE_DIR/template.yaml \
#       --build-dir $BASE_DIR/.aws-sam && \
#   sam package \
#       --template-file $BASE_DIR/.aws-sam/template.yaml \
#       --s3-bucket $ARTIFACTS_BUCKET \
#       --s3-prefix $SAM_PREFIX \
#       --output-template-file $BASE_DIR/output.yaml && \

#   sam deploy \
#       --template-file $BASE_DIR/output.yaml \
#       --stack-name vci-data-sfn_data_ingestion_pipeline \
#       --parameter-overrides \
#           TeamTag=$TEAM_TAG \
#           AWSTenant=$TENANT \
#           Env=$ENV \
#       --no-fail-on-empty-changeset

#   echo "Deploying sfn for Data Ingestion pipeline completed successfully!"
# }

# function sfn-run-data-ingestion-pipeline-delta-full {
#   echo "Deploying sfn for Data Ingestion pipeline delta and full Started"
#   BASE_DIR="$(pwd)/templates/sam/sfn-run-data-ingestion-pipeline-delta-full"
#   echo "Base Directory: $BASE_DIR"
#   sam build \
#       --template-file $BASE_DIR/template.yaml \
#       --build-dir $BASE_DIR/.aws-sam && \
#   sam package \
#       --template-file $BASE_DIR/.aws-sam/template.yaml \
#       --s3-bucket $ARTIFACTS_BUCKET \
#       --s3-prefix $SAM_PREFIX \
#       --output-template-file $BASE_DIR/output.yaml && \

#   sam deploy \
#       --template-file $BASE_DIR/output.yaml \
#       --stack-name vci-data-ingestion-pipeline-delta-full \
#       --parameter-overrides \
#           TeamTag=$TEAM_TAG \
#           AWSTenant=$TENANT \
#           Env=$ENV \
#       --no-fail-on-empty-changeset

#   echo "Deploying sfn for Data Ingestion pipeline delta and full completed successfully!"

# }

# function sfn-run-data-ingestion-pipeline-type2-dim {
#   echo "Deploying SF for Data Ingestion pipeline type2 Started"
#   BASE_DIR="$(pwd)/templates/sam/sfn-run-data-ingestion-pipeline-type2-dim"
#   echo "Base Directory: $BASE_DIR"
#   sam build \
#       --template-file $BASE_DIR/template.yaml \
#       --build-dir $BASE_DIR/.aws-sam && \
#   sam package \
#       --template-file $BASE_DIR/.aws-sam/template.yaml \
#       --s3-bucket $ARTIFACTS_BUCKET \
#       --s3-prefix $SAM_PREFIX \
#       --output-template-file $BASE_DIR/output.yaml && \

#   sam deploy \
#       --template-file $BASE_DIR/output.yaml \
#       --stack-name vci-data-ingestion-pipeline-type2-dim \
#       --parameter-overrides \
#           TeamTag=$TEAM_TAG \
#           AWSTenant=$TENANT \
#           Env=$ENV \
#       --no-fail-on-empty-changeset

#   echo "Deploying SF for Data Ingestion pipeline type2 completed successfully!"

# }

# function sfn-run-transformation-auction-fact {
#   echo "Deploying SF for Data Ingestion pipeline transform Started"
#   BASE_DIR="$(pwd)/templates/sam/sfn-run-transformation-auction-fact"
#   echo "Base Directory: $BASE_DIR"
#   sam build \
#       --template-file $BASE_DIR/template.yaml \
#       --build-dir $BASE_DIR/.aws-sam && \
#   sam package \
#       --template-file $BASE_DIR/.aws-sam/template.yaml \
#       --s3-bucket $ARTIFACTS_BUCKET \
#       --s3-prefix $SAM_PREFIX \
#       --output-template-file $BASE_DIR/output.yaml && \

#   sam deploy \
#       --template-file $BASE_DIR/output.yaml \
#       --stack-name vci-data-transformation-auction-fact \
#       --parameter-overrides \
#           TeamTag=$TEAM_TAG \
#           AWSTenant=$TENANT \
#           Env=$ENV \
#       --no-fail-on-empty-changeset

#   echo "Deploying SF for Data Ingestion pipeline transform completed successfully!"

# }


# function eventbridge {
#   echo "Deploying EventBridge rules"
#   BASE_DIR="$(pwd)/templates/eventbridge"
#   echo "Base Directory: $BASE_DIR"
#   aws cloudformation deploy \
#       --template-file  $BASE_DIR/s3-create-run-glue-database-crawler-rule.yaml \
#       --stack-name vci-datapipeline-create-crawler-eventbridge-rule-stack \
#       --parameter-overrides \
#           AWSTenant=$TENANT \
#           Env=$ENV \
#       --no-fail-on-empty-changeset

# aws cloudformation deploy \
#     --template-file $BASE_DIR/s3-raw-create-obj-trigger-lambda-rule.yaml \
#     --stack-name vci-datapipeline-trigger-lambda-eventbridge-rule-stack \
#     --parameter-overrides \
#         AWSTenant=$TENANT \
#         Env=$ENV \
#     --no-fail-on-empty-changeset
#   aws cloudformation deploy \
#     --template-file $BASE_DIR/rule-trigger-data-pipeline-type2.yaml \
#     --stack-name vci-datapipeline-trigger-type2-lambda-eventbridge-rule-stack \
#     --parameter-overrides \
#         AWSTenant=$TENANT \
#         Env=$ENV \
#     --no-fail-on-empty-changeset

# aws cloudformation deploy \
#     --template-file $BASE_DIR/rule-sfn-auction-fact.yaml \
#     --stack-name vci-datapipeline-trigger-acution-fact-lambda-eventbridge-rule-stack \
#     --parameter-overrides \
#         AWSTenant=$TENANT \
#         Env=$ENV \
#     --no-fail-on-empty-changeset

# aws cloudformation deploy \
#     --template-file $BASE_DIR/rule-glue-delay-notice.yaml \
#     --stack-name vci-datapipeline-send-glue-notice-eventbridge-rule-stack \
#     --parameter-overrides \
#         AWSTenant=$TENANT \
#         Env=$ENV \
#     --no-fail-on-empty-changeset

# aws cloudformation deploy \
#     --template-file $BASE_DIR/s3-axway-file-stage.yaml \
#     --stack-name vci-datapipeline-s3-axway-file-stage-eventbridge-rule-stack \
#     --parameter-overrides \
#         AWSTenant=$TENANT \
#         Env=$ENV \
#     --no-fail-on-empty-changeset

# aws cloudformation deploy \
#     --template-file $BASE_DIR/s3-lake-prebuild-conf.yaml \
#     --stack-name vci-datapipeline-s3-lake-prebuild-conf-eventbridge-rule-stack \
#     --parameter-overrides \
#         AWSTenant=$TENANT \
#         Env=$ENV \
#     --no-fail-on-empty-changeset    


#       echo "EventBridge completed successfully!"
# }

# function deploy_mwaa {

#     echo "Deploying mwaa"

#     MWAA_SECURITY_GROUP=$(aws cloudformation describe-stack-resources --stack-name vci-data-pipeline-sg-stack --logical-resource-id SelfReferencingSG | jq -r '.StackResources[0] | .PhysicalResourceId')
#     S3KEY=$(aws cloudformation describe-stack-resources --stack-name vci-data-pipeline-s3-stack --logical-resource-id S3Key | jq -r '.StackResources[0] | .PhysicalResourceId')

#     echo "  MWAAA SECURITY GROUP - $MWAA_SECURITY_GROUP"
#     echo "  MWAA S3KEY - $S3KEY"

#     BASE_DIR="$(pwd)/templates/mwaa"
#     echo "Base Directory: $BASE_DIR"
#     aws cloudformation deploy \
#         --capabilities CAPABILITY_IAM \
#         --template-file $BASE_DIR/mwaa.yml \
#         --stack-name vci-data-pipeline-mwaa-stack\
#         --parameter-overrides \
#             MWAAEnvironment=$MWAA_ENVIRONMENT \
#             Env=$ENV \
#             VPC=$VPC_ID \
#             PrivateSubnet1=$PRIVATE_SUBNET1  \
#             PrivateSubnet2=$PRIVATE_SUBNET2  \
#             MwaaSecurityGroup=$MWAA_SECURITY_GROUP \
#             AWSTenant=$TENANT \
#             TeamTag=$TEAM_TAG \
#             DsnaAccountId=$DSNA_ACCT_ID \
#             S3Key=$S3KEY \
#         --no-fail-on-empty-changeset
# }

# function deploy_mwaa_end_points {
#     echo "Deploying mwaa Endpoints"

#     MWAA_SECURITY_GROUP=$(aws cloudformation describe-stack-resources --stack-name vci-data-pipeline-sg-stack --logical-resource-id SelfReferencingSG | jq -r '.StackResources[0] | .PhysicalResourceId')
#     S3KEY=$(aws cloudformation describe-stack-resources --stack-name vci-data-pipeline-s3-stack --logical-resource-id S3Key | jq -r '.StackResources[0] | .PhysicalResourceId')

#     echo "  MWAAA SECURITY GROUP - $MWAA_SECURITY_GROUP"
#     echo "  MWAA S3KEY - $S3KEY"

#     BASE_DIR="$(pwd)/templates/security"
#     echo "Base Directory: $BASE_DIR"

#     aws cloudformation deploy \
#         --template-file $BASE_DIR/mwaa-end-points.yaml \
#         --stack-name vci-data-pipeline-mwaaep-stack \
#         --parameter-overrides \
#             Env=$ENV \
#             AWSTenant=$TENANT \
#             TeamTag=$TEAM_TAG \
#             VPC=$VPC_ID \
#             MwaaSecurityGroup=$MWAA_SECURITY_GROUP \
#             PrivateSubnet1=$PRIVATE_SUBNET1  \
#             PrivateSubnet2=$PRIVATE_SUBNET2  \
#             RouteTable1=$ROUTE_TABLE1 \
#             RouteTable2=$ROUTE_TABLE2 \
#         --no-fail-on-empty-changeset
# }


# function deploy_sfn_endpoint {

#     echo "Deploying sfn Endpoint"
#     SECURITY_GROUP=$(aws cloudformation describe-stack-resources --stack-name vci-data-pipeline-sg-stack --logical-resource-id SelfReferencingSG | jq -r '.StackResources[0] | .PhysicalResourceId')
#     SUBNET1=$(aws cloudformation describe-stack-resources --stack-name vpc --logical-resource-id db1Subnet | jq -r '.StackResources[0] | .PhysicalResourceId')
#     SUBNET2=$(aws cloudformation describe-stack-resources --stack-name vpc --logical-resource-id db2Subnet | jq -r '.StackResources[0] | .PhysicalResourceId')
#     SUBNET3=$(aws cloudformation describe-stack-resources --stack-name vpc --logical-resource-id app3Subnet | jq -r '.StackResources[0] | .PhysicalResourceId')
#     echo $SUBNET1
#     echo $SUBNET2
#     echo $SUBNET3
#     BASE_DIR="$(pwd)/templates/security"
#     echo "Base Directory: $BASE_DIR"
#     aws cloudformation deploy \
#         --template-file $BASE_DIR/vpc-endpoint.yaml \
#         --stack-name vci-data-pipeline-sfnep-stack \
#         --parameter-overrides \
#             Env=$ENV \
#             AWSTenant=$TENANT \
#             TeamTag=$TEAM_TAG \
#             SecurityGroupID=$SECURITY_GROUP\
#             VpcId=$VPC_ID \
#             subnet1=$SUBNET1  \
#             subnet2=$SUBNET2  \
#             subnet3=$SUBNET3 \
#         --no-fail-on-empty-changeset
# }

# function deploy_dynamic_gluejobs {
#     #DAGS_PATH=$(aws cloudformation describe-stack-resources --stack-name vci-data-pipeline-mwaa-stack --logical-resource-id EnvironmentS3Bucket | jq -r '.StackResources[0] | .PhysicalResourceId')
#     echo "Deploying dynamic glue jobs"
#     BASE_DIR="$(pwd)/templates/dags/dag_bag/"
#     # python $BASE_DIR/dynamic_glue_dag_generator.py

#     # python $BASE_DIR/dynamic_lambda_dag_generator.py

#     # aws s3 cp templates/dags/dag_bag/ s3://vw-cred-datalake-${ENV}-dags-store/dags/ --server-side-encryption=aws:kms --recursive
# }
