#!/usr/bin/bash
### Updated for bash version 4 or higher
################################## HEADER INFO #################################
### Purpose: Script to collect all Resource Requests
### Author: Russell Brown, rbrown@cohesity.com, +1 747.241.7117
### Created: 10/20/2023 Updated: 2/29/2024
### This script uses Mavenlink's REST API - developer.mavenlink.com
### This is the 3rd major revision to this weekly data collection process
########################### MAVENLINK BACKGROUND INFO ##########################
###REST API call - resource_requests generates a resource_id
###id can be found by searching for the workspace_id
###REST API call - workspace_resource_skills generates a list of skills
###searching for workspace_resource_id returns cached_kill_name, skill_id
###A single workspace_resource_id can have multiple skill_id but one workspace_id
###It appears a workspace_resource_id will have only one person assigned to it
############################# DEFINE MAVENLINK TOKEN ###########################
### Generate your Mavenlink Token and put it into a file called token.txt
authtoken=$(<token.txt)
########################### DEFINE COLUMN HEADINGS #############################
### This Array will contain the headings for all columns in the output
columnheadings () {
  columnhead=()
  columnhead+=("Date Requested")
  columnhead+=("Request ID")
  columnhead+=("Skill ID")
  columnhead+=("Skill Description")
  columnhead+=("Skill Level")
  columnhead+=("Requester ID")
  columnhead+=("Workspace Resource ID")
  columnhead+=("Person Assigned")
  columnhead+=("Project ID")
  columnhead+=("Project Title")
  numhead=$(echo "${#columnhead[@]}")
  echo "Number of Headings is $numhead"
}
columnheadings
########################### INITIALIZE OUTPUT FILE #############################
### Create output directory and initialize the final output file
iofilehandle=resource_request
finaloutputfile=resource_request_values
initializeoutput () {
  OUTPUT=output
  if [[ -d "$OUTPUT" ]]; then
      echo "Directory named - $OUTPUT - exists"
    else
      mkdir $OUTPUT
  fi
  # Using ^ as a column delimiter because = | and , are too common in data fields
  addtofile=""
  for u in "${columnhead[@]}"; do
    addtofile+="$u^"
  done
  :>$OUTPUT'/'$finaloutputfile'.txt'
  printf "$addtofile\n" >$OUTPUT'/'$finaloutputfile'.txt'
}
initializeoutput
########################### CONVERT OUTPUT TO JSON #############################
### function to clean up raw REST API output and convert to .json
### Many Mavenlink REST API calls return header info followed by payload on the last line
createjson () {
  tail -1 $iofilehandle'2.txt' >$iofilehandle'.txt'
  /usr/bin/python3 -m json.tool $iofilehandle'.txt' >$iofilehandle'.json'
  rm $iofilehandle'.txt' $iofilehandle'2.txt'
}
############################## COUNT RESOURCE REQUESTS #########################
### Determine how many pages of resource requests exist
activeresourcenumber () {
  curl -H 'Authorization: Bearer '$authtoken \
    'https://api.mavenlink.com/api/v1/workspace_resource_skills?per_page=1000' \
  >$iofilehandle'2.txt'
  createjson
  grep -A 2 '\"meta\"\:' $iofilehandle'.json' | grep page_count | cut -d : -f 2 | cut -d \, -f 1 | cut -c 2- | rev | cut -c 1- | rev >pagecount.txt
  grep -A 1 '\"meta\"\:' $iofilehandle'.json' | grep count | cut -d : -f 2 | cut -d \, -f 1 | cut -c 2- | rev | cut -c 1- | rev >totalrrcount.txt
  maxpagecount=$(<pagecount.txt)
  totalrrcount=$(<totalrrcount.txt)
  rm pagecount.txt totalrrcount.txt $iofilehandle'.json'
  echo "Found $totalrrcount Resource Requests on $maxpagecount Pages"
}
activeresourcenumber
################################################################################
### Function to get all resource requests and output to a .json file
getworkspaceskills() {
  curl -H 'Authorization: Bearer '$authtoken \
     'https://api.mavenlink.com/api/v1/workspace_resource_skills?include=skill,workspace_resource&page='$pagenum'&per_page=1000' \
     >$iofilehandle'2.txt'
  createjson
}
################################ GET KEY IDS ###################################
### Get Key IDs for all Keys Value Pairs
getentryids () {
  # Use the REST API output .json and extract the IDs
  grep -A 1 -e "\"key\":" $iofilehandle'.json' | grep '\"id\"' >$iofilehandle'.txt'
  # Cut out the 4th element of an array delimited by double quotes
  cut -d \" -f 4 $iofilehandle'.txt' >$iofilehandle'_ids.txt'
  # CLEANUP Temp File
  rm './'$iofilehandle'.txt'
}
############################### COLLECT VALUES #################################
### Get Data Values and output to a file
collectvalues () {
  while IFS= read -r requestid; do
    outputline=()
    grep -A 9 -e "\"$requestid\":" $iofilehandle'.json' >resourcetmp.txt
    date_created=$(grep -e 'created_at' resourcetmp.txt | cut -d \" -f 4 | cut -c 1-10)
    outputline+=("$date_created")
    outputline+=("$requestid")
    skillid=$(grep -e 'skill_id' resourcetmp.txt | cut -d \" -f 4)
    outputline+=("$skillid")
    skilldesc=$(grep -e 'cached_skill_name' resourcetmp.txt | cut -d \" -f 4)
    outputline+=("$skilldesc")
    skilllvl=$(grep -e "\"level\"" resourcetmp.txt | cut -d : -f 2 | cut -c 2- | rev | cut -c 2- | rev)
    outputline+=("$skilllvl")
    requesterid=$(grep -e 'creator_id' resourcetmp.txt | cut -d \" -f 4)
    outputline+=("$requesterid")
    wkspc_resource_id=$(grep -e 'workspace_resource_id' resourcetmp.txt | cut -d \" -f 4)
    outputline+=("$wkspc_resource_id")
    userassigned=$(grep -A 23 -e "\""$wkspc_resource_id"\": {" $iofilehandle'.json' | grep -e 'display_label' | cut -d \" -f 4)
    outputline+=("$userassigned")
    projid=$(grep -A 23 -e "\""$wkspc_resource_id"\": {" $iofilehandle'.json' | grep -e 'workspace_id' | cut -d : -f 2 | cut -c 2- | rev | cut -c 2- | rev)
    outputline+=("$projid")
    projtitle=$(grep -A 23 -e "\""$wkspc_resource_id"\": {" $iofilehandle'.json' | grep -e 'workspace_title' | cut -d \" -f 4)
    outputline+=("$projtitle")
    # Using = as column delimiter because | and , are too common in data fields
    outtofile=""
    for x in "${outputline[@]}"; do
      outtofile+="$x^"
    done
    echo "$outtofile" >>$OUTPUT'/'$finaloutputfile'.txt'
  done <$iofilehandle'_ids.txt'
  rm resourcetmp.txt $iofilehandle'_ids.txt'
}
################################## MAIN BODY ###################################
### Iterate through all pages to generate Resource Request output
getallresourcerequests () {
  pagenum=1
  pagestoprocess=$maxpagecount
  ((maxpagecount++))
  while (( $pagenum < $maxpagecount )); do
    getworkspaceskills
    getentryids
    collectvalues
    mv $iofilehandle'.json' $OUTPUT'/'$iofilehandle'_'$pagenum'.json'
    echo "Processed Page $pagenum of $pagestoprocess"
    ((pagenum++))
  done
}
getallresourcerequests