#!/bin/bash
################################################################################
# Author - Russell Brown
# Contact Email: rbrown@cohesity.com
# Contact Phone: +1 747.241.7117
# Creation Date: 14 August 2023
# Last Updated: 7 September 2023
################################################################################
# Mavenlink REST API bash script to collect All Skills
################################################################################
# You will need to generate your Mavenlink Token and put it into a file called token.txt
authtoken=$(<token.txt)
################################################################################
# Create output directory and initialize the final output file
finaloutputfile=all_skills_details
initializeoutput () {
  OUTPUT=output
  if [[ -d "$OUTPUT" ]]; then
      echo "Directory named - $OUTPUT - exists"
    else
      mkdir $OUTPUT
  fi
  :>$OUTPUT'/'$finaloutputfile'.txt'
  printf "Skill Name=Skill Category ID=Skill ID\n" >$OUTPUT'/'$finaloutputfile'.txt'
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
# Determine how many pages of skills exist
iofilehandle=skills
allskillsnumber () {
  curl -H 'Authorization: Bearer '$authtoken \
  'https://api.mavenlink.com/api/v1/skills?&order=alphabetical%3Aasc&page=1&per_page=200' \
  >$iofilehandle'2.txt'
  createjson
  grep -A 2 '\"meta\"\:' $iofilehandle'.json' | grep page_count | cut -d : -f 2 | cut -d \, -f 1 | cut -c 2- | rev | cut -c 1- | rev >pagecount.txt
  grep -A 1 '\"meta\"\:' $iofilehandle'.json' | grep count | cut -d : -f 2 | cut -d \, -f 1 | cut -c 2- | rev | cut -c 1- | rev >totalskillcount.txt
  maxpagecount=$(<pagecount.txt)
  totalskillcount=$(<totalskillcount.txt)
  rm pagecount.txt totalskillcount.txt $iofilehandle'.json'
  echo "Found $totalskillcount Skills on $maxpagecount Pages"
}
allskillsnumber
################################################################################
# Get Skill IDs for all skills
getentryids () {
  # Take the REST API output file and extract the skill ids
  grep -A 1 -e "\"key\":" $iofilehandle'.json' | grep '\"id\"' >$iofilehandle'.txt'
  # Cut out the 4th element of an array delimited by double quotes
  cut -d \" -f 4 $iofilehandle'.txt' >$iofilehandle'_ids.txt'
  # CLEANUP Temp File
  rm './'$iofilehandle'.txt'
}
################################################################################
# Get Values for each Skill ID
getskillvalues () {
  while read -r skillid; do
    grep -A 8 "\""$skillid"\": {" $iofilehandle'.json' >./skillstemp.txt
    grep -e "\"name\":" -e "\"id\":" -e "\"skill_category_id\":" ./skillstemp.txt | cut -d \" -f 4 >>$OUTPUT'/'$skillid'.txt'
  done <$iofilehandle'_ids.txt'
  rm ./skillstemp.txt
}
################################################################################
# Format output and publish to aggregate output file
organizeoutput () {
  while read -r skillid; do
    valueline=()
    while read -r skillval; do
      skillval=$skillval'='
      valueline+=("$skillval")
    done <$OUTPUT'/'$skillid'.txt'
    rm $OUTPUT'/'$skillid'.txt'
    echo ${valueline[*]} >>$OUTPUT'/'$finaloutputfile'.txt'
  done <$iofilehandle'_'$pagenum'_ids.txt'
}
################################################################################
# Clean Up extra spaces after equals sign delimiter
# this method uses the editor ex to globally substitute values
cleanspaces () {
  ex -s -c '%s/= /=/g|x' $OUTPUT'/'$finaloutputfile'.txt'
}
################################################################################
# Get Skill Details for all skills
getskilldetails () {
  pagenum=1
  pagestoprocess=$maxpagecount
  ((maxpagecount++))
  while (( $pagenum < $maxpagecount )); do
    curl -H 'Authorization: Bearer '$authtoken \
    'https://api.mavenlink.com/api/v1/skills?&order=alphabetical%3Aasc&page='$pagenum'&per_page=200' \
    >$iofilehandle'2.txt'
    createjson
    getentryids
    echo "Obtained all Skill IDs for Page $pagenum"
    getskillvalues
    echo "Captured Skill Values for Page $pagenum"
    mv $iofilehandle'.json' $iofilehandle'_'$pagenum'.json'
    mv $iofilehandle'_ids.txt' $iofilehandle'_'$pagenum'_ids.txt'
    organizeoutput
#    rm $iofilehandle'_'$pagenum'.json' $iofilehandle'_'$pagenum'_ids.txt'
    echo "Processed Page $pagenum of $pagestoprocess"
    ((pagenum++))
  done
}
getskilldetails
cleanspaces
echo "script found $totalskillcount skills on $pagestoprocess pages"
