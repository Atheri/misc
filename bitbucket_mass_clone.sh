PROJECT=$1
PAGE=$2
ORG='<ORG>'

for r in $(curl --location --request GET "https://api.bitbucket.org/2.0/repositories/${ORG}?q=project.key=%22${PROJECT}%22&pagelen=100&page=${PAGE}" -u "$BITBUCKET_USER:$BITBUCKET_PASSWORD" | jq '.values[].links.clone[] | select(.name == "ssh") | .href' | sed 's/"//g')
do
  ((i=i+1))
  echo "##############$r"
  git clone $r
done
echo "$i"
