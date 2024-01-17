#!/bin/bash
################################################################################
# Author - Russell Brown
# Contact Email: rbrown@cohesity.com
# Contact Phone: +1 747.241.7117
# Creation Date: 8 September 2023
# Last Updated: 8 September 2023
# Mavenlink API call to bulk update attributes of skill entries
# NOTE: This script updates the skills themselves, not users memberships
################################################################################
# You will need to generate your Mavenlink Token and put it into a file called token.txt
authtoken=$(<token.txt)
# Initialize I/O file
iofilehandle=skillupdate
:>$iofilehandle'.txt'
# CSV file format is "name/description",skill_id,skill_category_id
inputfile=skillsupdate.csv
################################################################################
# Check for and create the Output directory if needed
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
# Begin processing updates for all Skill IDs
echo "Updating Skills"
count=0
while IFS= read -r updateskill; do
  namedesc=$(echo $updateskill | cut -d \, -f 1)
  skillid=$(echo $updateskill | cut -d \, -f 2)
  skillcatid=$(echo $updateskill | cut -d \, -f 3)
  echo "Updating $namedesc $skillid $skillcatid"
  curl -i -X PUT \
  --url 'https://api.mavenlink.com/api/v1/skills/'$skillid \
  -H 'Authorization: Bearer '$authtoken \
  -H 'Content-Type: application/json' \
  -d '{
    "skill": {
      "name": "'"$namedesc"'",
      "description": "'"$namedesc"'"
      }
  }' \
  >$iofilehandle'2.txt'
  createjson
  mv $iofilehandle'.json' $OUTPUT'/'$skillid'.json'
  ((count++))
done <$inputfile
echo "Updated $count Skill Entries"
