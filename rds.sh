#!/usr/local/bin/bash

# TODO Update for accounts in question
SOURCE_ACCOUNT="<PROFILE>"
SOURCE_ACCOUNT_ID="111111111111"
TARGET_ACCOUNT="<PROFILE>"
TARGET_ACCOUNT_ID="222222222222"
######################################

START_TIME=$(date +'%r')
echo "Start Time: $START_TIME"

SOURCE_DB="<NAME>"
SNAPSHOT_ID="$SOURCE_DB-MANUAL-CJL"

# source account
function setSourceAws() {
  echo "--- set AWS_PROFILE=$SOURCE_ACCOUNT ---"
  export AWS_PROFILE=$SOURCE_ACCOUNT
}

# target account
function setTargetAws() {
  echo "--- set AWS_PROFILE=$TARGET_ACCOUNT ---"
  export AWS_PROFILE=$TARGET_ACCOUNT
}

SNAPSHOT_STATUS="none"
function getSnapshotStatus() {
  SNAPSHOT_STATUS=$(aws rds describe-db-snapshots --query "DBSnapshots[?@.DBSnapshotIdentifier=='$SNAPSHOT_ID']" | jq -r '.[0].Status')
  echo "$(date +'%r'): Snapshot Status - $SNAPSHOT_STATUS"
}

RESTORED_DB_STATUS="none"
function getDBStatus() {
  RESTORED_DB_STATUS=$(aws rds describe-db-instances --query "DBInstances[?@.DBInstanceIdentifier=='$SOURCE_DB']" | jq -r '.[0].DBInstanceStatus')
  echo "$(date +'%r'): DB Status - $RESTORED_DB_STATUS"
}

function pressKeyToContinue() {
  read -p "Press enter to continue"
}

### Source Account ###
setSourceAws

echo "--- Creating snapshot of $SOURCE_DB ---"
aws rds create-db-snapshot \
  --db-instance-identifier "$SOURCE_DB" \
  --db-snapshot-identifier "$SNAPSHOT_ID"

exit
echo "--- Waiting for the source account snapshot to be available ---"
getSnapshotStatus
while [[ "$SNAPSHOT_STATUS" != "available" ]]; do
  sleep 10
  getSnapshotStatus
done

echo "--- Sharing snapshot ---"
aws rds modify-db-snapshot-attribute \
  --db-snapshot-identifier "$SNAPSHOT_ID" \
  --attribute-name restore  \
  --values-to-add "[\"$TARGET_ACCOUNT_ID\"]"

### Target Account ###
setTargetAws

echo "--- Getting KMS key arn ---"
KMS_ALIAS_ARN=$(aws kms list-aliases --query "Aliases[?contains(@.AliasName,'$ENV-$PRODUCT')]" | jq -r '.[0].AliasArn')
echo "$KMS_ALIAS_ARN"

echo "--- Copying to target account ---"
aws rds copy-db-snapshot \
  --source-db-snapshot-identifier "arn:aws:rds:us-west-2:$SOURCE_ACCOUNT_ID:snapshot:$SNAPSHOT_ID" \
  --target-db-snapshot-identifier "$SNAPSHOT_ID" \
  --kms-key-id "$KMS_ALIAS_ARN"

echo "--- Waiting for the target account snapshot to be available ---"
getSnapshotStatus
while [[ "$SNAPSHOT_STATUS" != "available" ]]; do
  sleep 10
  getSnapshotStatus
done

echo "--- Getting Security Group ID ---"
SG_ID=$(aws ec2 describe-security-groups --query "SecurityGroups[?contains(@.GroupName,'${ENV^^}-${PRODUCT^^}')]" | jq -r '.[0].GroupId')
echo "$SG_ID"

echo "--- Getting Parameter Group Name ---"
PARAM_GROUP=$(aws rds describe-db-parameter-groups --query "DBParameterGroups[?contains(@.DBParameterGroupName,'$ENV-$PRODUCT')]" | jq -r '.[0].DBParameterGroupName')
echo "$PARAM_GROUP"

echo "--- Getting Subnet Group Name ---"
SUBNET_NAME=$(aws rds describe-db-subnet-groups --query "DBSubnetGroups[?contains(@.DBSubnetGroupName,'$ENV-$PRODUCT')]" | jq -r '.[0].DBSubnetGroupName')
echo "$SUBNET_NAME"

echo "--- Restoring DB in target account ---"
aws rds restore-db-instance-from-db-snapshot \
  --db-instance-identifier "$SOURCE_DB" \
  --db-snapshot-identifier "$SNAPSHOT_ID" \
  --db-subnet-group-name "$SUBNET_NAME" \
  --vpc-security-group-ids "$SG_ID" \
  --db-parameter-group-name "$PARAM_GROUP"


echo "--- Waiting for restored DB to be available ---"
getDBStatus
while [[ "$RESTORED_DB_STATUS" != "available" ]]; do
  sleep 10
  getDBStatus
done

END_TIME=$(date +'%r')
echo "Start Time: $START_TIME"
echo "End Time  : $END_TIME"

pressKeyToContinue

#todo testing
echo "--- Deleting source account snapshot for testing ---"
setSourceAws
aws rds delete-db-snapshot --db-snapshot-identifier "$SNAPSHOT_ID"

setTargetAws
echo "--- Deleting target account snapshot for testing ---"
aws rds delete-db-snapshot --db-snapshot-identifier "$SNAPSHOT_ID"
echo "--- Deleting target account DB for testing ---"
aws rds delete-db-instance --db-instance-identifier "$SOURCE_DB" --skip-final-snapshot
getDBStatus
while [[ "$RESTORED_DB_STATUS" != "null" ]]; do
  sleep 10
  getDBStatus
done
