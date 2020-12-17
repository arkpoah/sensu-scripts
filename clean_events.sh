#!bin/bash

data=$(sensuctl event list --all-namespaces --format json)
keepalives=()
checks=()
delentities=()

is_in_entity () {
  for entity in "${delentities[@]}"
  do
     if echo "$1" | grep -q $entity; then
        return 0
     fi
  done
  return 1
}

for row in $(echo "${data}" | jq -r '.[] | @base64'); do
    _jq() {
     echo ${row} | base64 --decode | jq -r ${1}
    }

   check=$(_jq '.check.metadata.name')
   namespace=$(_jq '.check.metadata.namespace')
   entity=$(_jq '.entity.metadata.name')
   executed=$(date -I -d @$(_jq '.check.executed'))
   issued=$(date -I -d @$(_jq '.check.issued'))
   last_ok=$(date -I -d @$(_jq '.check.last_ok'))
   date_limit=$(date -I -d "-1 day")
   apt_date_limit=$(date -I -d "-3 day")

   #echo "${check} ${entity} e: ${executed} i:${issued} l: ${last_ok} d: ${date_limit}"
   if [ "$check" == "keepalive" ];
   then
     if [[ "$last_ok" < "$date_limit" ]];
     then
        delentities+=( $entity )
        keepalives+=( "/usr/bin/sensuctl entity delete ${entity} --namespace ${namespace} --skip-confirm" )
     fi
   elif [ "$check" == "apt-security" ];
   then
     if [[ "$executed" < "$apt_date_limit" ]];
     then
        checks+=( "/usr/bin/sensuctl event delete ${entity} ${check} --namespace ${namespace} --skip-confirm" )
     fi
   else
     if [[ "$executed" < "$date_limit" ]];
     then
        checks+=( "/usr/bin/sensuctl event delete ${entity} ${check} --namespace ${namespace} --skip-confirm" )
     fi
  fi
done

for keepalive in "${keepalives[@]}"
do
  n=$(echo $keepalive | cut -f 6 -d ' ')
  e=$(echo $keepalive | cut -f 4 -d ' ')
  echo "[$n] Deleting $e entity..."
  eval $keepalive
done
for check in "${checks[@]}"
do
  if ! is_in_entity "${check}"; then
    n=$(echo $check | cut -f 7 -d ' ')
    c=$(echo $check | cut -f 5 -d ' ')
    e=$(echo $check | cut -f 4 -d ' ')
    echo "[$n] Deleting $c event on $e entity..."
    eval $check
  fi
done
