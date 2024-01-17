#!/bin/bash
################################################################################
# Purpose: Script to Update Mavenlink Skill Membership Levels
# Author: Russell Brown - rbrown@cohesity.com - +1 747.241.7117
# Created: 9/11/2023  Last Updated: 9/11/2023
################################################################################
# You will need to generate your Mavenlink Token and put it into a file called token.txt
authtoken=$(<token.txt)
# Read in Skill Membership IDs to update in the format: membership_id,skill_level
inputfile="updateskilllevels.txt"
# Definine I/O Filehandle
iofilehandle=skillmemlevel
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
updateskilllevel () {
  count=0
  while IFS= read -r changelist; do
    skillmemid=$(echo $changelist | cut -d \, -f 1)
    skillnewlvl=$(echo $changelist | cut -d \, -f 2)
    echo "Updating $skillmemid to Skill Level $skillnewlvl"
    curl -i -X PUT \
      --url 'https://api.mavenlink.com/api/v1/skill_memberships/'$skillmemid \
      -H 'Authorization: Bearer '$authtoken \
      -H 'Content-Type: application/json' \
      -d '{
        "skill_membership": {
          "level": '$skillnewlvl'
        }
      }' \
      >$iofilehandle'2.txt'
    createjson
    mv $iofilehandle.json $OUTPUT'/'$skillmemid'.json'
    ((count++))
  done <$inputfile 
  echo "Updated $count Skill Memberships"
}
updateskilllevel
