#!/bin/bash

print_seperator() {
  text=$1
  symbol=$2

  remain_n=$(( cols-${#text} ))
  fill=""
  for (( i=0; i<remain_n; i++ ))
  do
    fill=$fill$symbol
  done
  printf "%s%s\\n" "$text" "$fill"
}

## MAIN ##
set =x 
rm -f output.txt
for dir in */
do
  cols=$(tput cols)

  if git -C "$dir" rev-parse &> /dev/null; then
    branch_name=$(git -C "$dir" rev-parse --abbrev-ref HEAD)
    if ! [ -z "$(git -C "$dir" status --porcelain)" ]; then
      echo "${dir} - ${branch_name} - dirty" >> output.txt
    elif ! [[ ${branch_name} =~ "master" ]]; then
      if ! [[ ${branch_name} =~ "main" ]]; then
        if ! [[ ${branch_name} =~ "develop" ]]; then
          echo "${dir} - ${branch_name}" >> output.txt
        fi
      fi
    fi

    message="----# $dir$branch_name #"
    
    print_seperator "$message" "-"
    
    git -C "$dir" pull --ff-only
  fi
done
## END MAIN ##
