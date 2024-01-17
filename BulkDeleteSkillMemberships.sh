#!/bin/bash
################################################################################
# Author - Russell Brown
# Contact Email: rbrown@cohesity.com
# Contact Phone: +1 747.241.7117
# Creation Date: 5 September 2023
# Last Updated: 11 September 2023
# Mavenlink API call to Bulk DELETE skill memberships from an input file
################################################################################
# You will need to generate your Mavenlink Token and put it into a file called token.txt
authtoken=$(<token.txt)
# Read in Skill Membership IDs from a file
inputfile=deleteskillmembershipids.txt
# Initialize I/O file
iofilehandle=delskillmembers
:>$iofilehandle'.txt'
################################################################################
# Create output directory and initialize the final output file
finaloutputfile=deleted_skillmemberships
initializeoutput () {
  OUTPUT=output
  if [[ -d "$OUTPUT" ]]; then
      echo "Directory named - $OUTPUT - exists"
    else
      mkdir $OUTPUT
  fi
  :>$OUTPUT'/'$finaloutputfile'.txt'
}
initializeoutput
################################################################################
# Begin processing all Participation IDs
while IFS= read -r membershipid; do
  echo "Skills Membership ID " $membershipid
  curl -i -X DELETE \
    --url 'https://api.mavenlink.com/api/v1/skill_memberships/'$membershipid \
    -H 'Authorization: Bearer '$authtoken \
    -H 'Content-Type: application/json' \
    >$OUTPUT/$membershipid'.txt'
  echo 'Deleted ID '$membershipid >>$OUTPUT'/'$finaloutputfile'.txt'
done <$inputfile
# A successful Skill Membership Deletion will return a code 204 that looks like this:
# HTTP/1.1 204 No Content
# followed by other inconsequential information