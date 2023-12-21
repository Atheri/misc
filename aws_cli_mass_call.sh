#!/opt/homebrew/bin/bash
commands=("$@")

# get all the account ids in the our org
mapfile -t orgs < <(aws organizations list-accounts --profile clearcapital-main | jq  -r ".Accounts[].Id")

# for each org run the aws command
not_queried=()
for id in "${orgs[@]}"
do
  account_name=$(aws organizations describe-account --account-id $id --profile clearcapital-main --no-cli-pager --query 'Account.Name')
  profile="DevOps-$id"
  if ! output="$(aws "${commands[@]}" --profile "$profile" --no-cli-pager)";
  then
    not_queried+=("$id")
    echo "FAILURE"
  fi
  echo "$id - $account_name =================================================================="
  echo -e "$output\n"

done

# print the failed accounts
if (( ${#not_queried[@]} )); then
  echo "Accounts where command failed: "
  for id in "${not_queried[@]}"
  do
    echo "  $id"
  done
fi
