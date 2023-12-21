#!/usr/bin/bash

# TODO Update for accounts in question
SOURCE_ACCOUNT="<PROFILE>"
SOURCE_ACCOUNT_ID="111111111111"
TARGET_ACCOUNT="<PROFILE>"
TARGET_ACCOUNT_ID="222222222222"
######################################

export AWS_PAGER=
START_TIME=$(date +'%r')
echo "Start Time: $START_TIME"

SOURCE_DB="<NAME>"
SNAPSHOT_ID="$SOURCE_DB-manual-cjl"

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
  SNAPSHOT=$(aws rds describe-db-cluster-snapshots --query "DBClusterSnapshots[?@.DBClusterSnapshotIdentifier=='$1']")
  SNAPSHOT_STATUS=$(echo "$SNAPSHOT" | jq -r '.[0].Status')
  SNAPSHOT_PROGRESS=$(echo "$SNAPSHOT" | jq -r '.[0].PercentProgress')
  echo "$(date +'%r'): Snapshot Status - $SNAPSHOT_STATUS - $SNAPSHOT_PROGRESS%"
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
aws rds create-db-cluster-snapshot \
  --db-cluster-snapshot-identifier "$SNAPSHOT_ID" \
  --db-cluster-identifier "$SOURCE_DB"

echo "--- Waiting for the source account snapshot to be available ---"
getSnapshotStatus $SNAPSHOT_ID
while [[ "$SNAPSHOT_STATUS" != "available" ]]; do
  sleep 10
  getSnapshotStatus $SNAPSHOT_ID
done
echo "--- Copying to snapshot to other region ---"
KMS_ALIAS_ARN_SOURCE_EAST="arn:aws:kms:us-east-1:736018059497:alias/dr-test-2022-02-01-cjl"
SNAPSHOT_ID_EAST="$SNAPSHOT_ID-east"
SNAPSHOT_ARN_WEST="arn:aws:rds:us-west-2:$SOURCE_ACCOUNT_ID:cluster-snapshot:$SNAPSHOT_ID"
SNAPSHOT_ARN_EAST="arn:aws:rds:us-east-1:$SOURCE_ACCOUNT_ID:cluster-snapshot:$SNAPSHOT_ID_EAST"
export AWS_REGION=us-east-1
aws rds copy-db-cluster-snapshot \
  --source-db-cluster-snapshot-identifier "$SNAPSHOT_ARN_WEST" \
  --target-db-cluster-snapshot-identifier "$SNAPSHOT_ID_EAST" \
  --kms-key-id "$KMS_ALIAS_ARN_SOURCE_EAST"

echo "--- Waiting for the east snapshot to be available ---"
getSnapshotStatus $SNAPSHOT_ID_EAST
while [[ "$SNAPSHOT_STATUS" != "available" ]]; do
  sleep 10
  getSnapshotStatus $SNAPSHOT_ID_EAST
done

echo "--- Sharing snapshot ---"
aws rds modify-db-cluster-snapshot-attribute \
  --db-cluster-snapshot-identifier "$SNAPSHOT_ID_EAST" \
  --attribute-name restore  \
  --values-to-add "[\"$TARGET_ACCOUNT_ID\"]"
exit
### Target Account ###
setTargetAws

echo "--- Getting KMS key arn ---"
#KMS_ALIAS_ARN=$(aws kms list-aliases --query "Aliases[?contains(@.AliasName,'$ENV-$PRODUCT')]" | jq -r '.[0].AliasArn')
KMS_ALIAS_ARN="arn:aws:kms:us-east-1:464932029236:alias/rds/drssot-prod-postgres"
echo "$KMS_ALIAS_ARN"

echo "--- Copying to target account ---"
aws rds copy-db-cluster-snapshot \
  --source-db-cluster-snapshot-identifier "$SNAPSHOT_ARN_EAST" \
  --target-db-cluster-snapshot-identifier "$SNAPSHOT_ID_EAST" \
  --kms-key-id "$KMS_ALIAS_ARN_SOURCE_EAST"

echo "--- Waiting for the target account snapshot to be available ---"
getSnapshotStatus $SNAPSHOT_ID_EAST
while [[ "$SNAPSHOT_STATUS" != "available" ]]; do
  sleep 10
  getSnapshotStatus $SNAPSHOT_ID_EAST
done
#
#echo "--- Getting Security Group ID ---"
#SG_ID=$(aws ec2 describe-security-groups --query "SecurityGroups[?contains(@.GroupName,'${ENV^^}-${PRODUCT^^}')]" | jq -r '.[0].GroupId')
#echo "$SG_ID"
#
#echo "--- Getting Parameter Group Name ---"
#PARAM_GROUP=$(aws rds describe-db-parameter-groups --query "DBParameterGroups[?contains(@.DBParameterGroupName,'$ENV-$PRODUCT')]" | jq -r '.[0].DBParameterGroupName')
#echo "$PARAM_GROUP"
#
#echo "--- Getting Subnet Group Name ---"
#SUBNET_NAME=$(aws rds describe-db-subnet-groups --query "DBSubnetGroups[?contains(@.DBSubnetGroupName,'$ENV-$PRODUCT')]" | jq -r '.[0].DBSubnetGroupName')
#echo "$SUBNET_NAME"
#
#echo "--- Restoring DB in target account ---"
#aws rds restore-db-instance-from-db-snapshot \
#  --db-instance-identifier "$SOURCE_DB" \
#  --db-snapshot-identifier "$SNAPSHOT_ID" \
#  --db-subnet-group-name "$SUBNET_NAME" \
#  --vpc-security-group-ids "$SG_ID" \
#  --db-parameter-group-name "$PARAM_GROUP"
#
#
#echo "--- Waiting for restored DB to be available ---"
#getDBStatus
#while [[ "$RESTORED_DB_STATUS" != "available" ]]; do
#  sleep 10
#  getDBStatus
#done
#
END_TIME=$(date +'%r')
echo "Start Time: $START_TIME"
echo "End Time  : $END_TIME"

pressKeyToContinue

#todo testing
echo "--- Deleting source account snapshot for testing ---"
setSourceAws
aws rds delete-db-cluster-snapshot --db-cluster-snapshot-identifier "$SNAPSHOT_ID"

setTargetAws
echo "--- Deleting target account snapshot for testing ---"
aws rds delete-db-cluster-snapshot --db-cluster-snapshot-identifier "$SNAPSHOT_ID"
#echo "--- Deleting target account DB for testing ---"
#aws rds delete-db-instance --db-instance-identifier "$SOURCE_DB" --skip-final-snapshot
#getDBStatus
#while [[ "$RESTORED_DB_STATUS" != "null" ]]; do
#  sleep 10
#  getDBStatus
#done
