#!/bin/bash
################################################################################
# Purpose: Script to Create Mavenlink Skill Membership Levels
# Author: Russell Brown - rbrown@cohesity.com - +1 747.241.7117
# Created: 9/12/2023  Last Updated: 10/02/2023
################################################################################
# You will need to generate your Mavenlink Token and put it into a file called token.txt
authtoken=$(<token.txt)
# Read in Skill Membership IDs to update in the format: skillid,userid,skill_level
inputfile="newskills.txt"
# Definine I/O Filehandle
iofilehandle=newskillmem
################################################################################
# Check or create output directory
initializeoutput () {
  OUTPUT=output
  if [[ -d "$OUTPUT" ]]; then
      echo "Directory named - $OUTPUT - exists"
    else
      mkdir $OUTPUT
  fi
}
initializeoutput
################################################################################
# function to clean up raw REST API output and convert to .json
# Many Mavenlink REST API calls return header info first with payload on last line
createjson () {
  tail -1 $iofilehandle'2.txt' >$iofilehandle'.txt'
  /usr/bin/python3 -m json.tool $iofilehandle'.txt' >$iofilehandle'.json'
  rm $iofilehandle'.txt' $iofilehandle'2.txt'
}
################################################################################
createskillmem () {
  count=0
  while IFS= read -r addlist; do
    skillid=$(echo $addlist | cut -d \, -f 1)
    userid=$(echo $addlist | cut -d \, -f 2)
    skilllvl=$(echo $addlist | cut -d \, -f 3)
    echo "Creating Skill Membership for $skillid for $userid at Level $skilllvl"
    curl -i -X POST \
      --url 'https://api.mavenlink.com/api/v1/skill_memberships?' \
      -H 'Authorization: Bearer '$authtoken \
      -H 'Content-Type: application/json' \
      -d '{
        "skill_membership": {
          "skill_id": '$skillid',
          "user_id": '$userid',
          "level": '$skilllvl'
        }
      }' \
      >$iofilehandle'2.txt'
    createjson
    mv $iofilehandle.json $OUTPUT'/'$userid'_'$skillid'.json'
    ((count++))
  done <$inputfile 
  echo "Created $count Skill Memberships"
}
createskillmem
