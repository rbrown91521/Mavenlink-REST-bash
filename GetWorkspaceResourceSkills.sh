#!/bin/bash
################################################################################
# Author - Russell Brown
# Contact Email: rbrown@cohesity.com
# Contact Phone: +1 747.241.7117
# Creation Date: 13 June 2023
# Last Updated: 23 June 2023
# Mavenlink API call to get Skills for all Workspaces
################################################################################
#REST API call - resource_requests generates a resource_id
#id can be found by searching for the workspace_id
################################################################################
#REST API call - workspace_resource_skills generates a list of skills
#searching for workspace_resource_id returns cached_kill_name, skill_id
#A single workspace_resource_id can have multiple skill_id but one workspace_id
#It appears that a workspace_resource_id will have only one person assigned to it
################################################################################
# Please create a directory called "output" in the local directory where you run this script
iofilehandle=workspace_skills
# You will need to generate your Mavenlink Token and put it into a file called token.txt
authtoken=$(<token.txt)
################################################################################
# Function to get all resource requests and output to a .json file
getworkspaceskills() {
  curl -H 'Authorization: Bearer '$authtoken \
     'https://api.mavenlink.com/api/v1/workspace_resource_skills?include=skill,workspace_resource&per_page=1000' \
     >$iofilehandle'2.txt'
  ################################################################################
  # CONVERT output to json file
  # Many Mavenlink REST API calls return header info with the payload on the last line
  tail -1 $iofilehandle'2.txt' >$iofilehandle'.txt'
  /usr/bin/python3 -m json.tool $iofilehandle'.txt' >$iofilehandle'.json'
  ################################################################################
  # Cleanup temporary files
  rm $iofilehandle'2.txt' $iofilehandle'.txt'
}
getworkspaceskills
# Grab the Workspace Resource IDs
grep -A 1 key $iofilehandle'.json' | grep id | cut -d \" -f 4 | sort >workspace_resource_ids.txt
################################################################################
# From the output file, grab the values for the skill, the user, the date, etc.
# Output to a comma delimited file rather than a pipe delimited file
filterdetails () {
  while IFS= read -r wkspc_res_id; do
    grep -A 9 -e "\"$wkspc_res_id\":" $iofilehandle'.json' | tail -9 >$wkspc_res_id'_2.txt'
    # Get the Date when the Resource Request was created
    grep -e 'created_at' $wkspc_res_id'_2.txt' >$wkspc_res_id'_b.txt'
    cut -d \" -f 4 $wkspc_res_id'_b.txt' | cut -c 1-10 >$wkspc_res_id'.txt'
    # Get the non numeric values except for the workspace_resource_id
    grep -e "\"id\"" -e 'creator_id' -e 'skill_id' -e 'cached_skill_name' $wkspc_res_id'_2.txt' >$wkspc_res_id'_a.txt'
    cut -d \" -f 4 $wkspc_res_id'_a.txt' >>$wkspc_res_id'.txt'
    # Get the numeric values
    grep -e "\"level\":" $wkspc_res_id'_2.txt' >$wkspc_res_id'_c.txt'
    cut -d : -f 2 $wkspc_res_id'_c.txt' | cut -c 2- | rev | cut -c 2- | rev >>$wkspc_res_id'.txt'
    # Get the workspace_resource_id which we'll use to get the Project ID and Title
    grep -e 'workspace_resource_id' $wkspc_res_id'_2.txt' >temp2.txt
    cut -d \" -f 4 temp2.txt >temp.txt
    # Also append workspace_resource_id to the file where we're collecting the values
    cut -d \" -f 4 temp2.txt >>$wkspc_res_id'.txt'
    # Grab the Project ID and Project Title
    workspace_resource_id=$(<temp.txt)
    # I'm reusing the b temp file for the project id which is a numeric value
    grep -A 5 -e "\"$workspace_resource_id\":" $iofilehandle'.json' | grep -e "workspace_id" >$wkspc_res_id'_b.txt'
    cut -d : -f 2 $wkspc_res_id'_b.txt' | cut -c 2- | rev | cut -c 2- | rev >>$wkspc_res_id'.txt'
    # I'm reusing the a temp file for the title which is a non numeric value
    grep -A 5 -e "\"$workspace_resource_id\":" $iofilehandle'.json' | grep -e "workspace_title" >$wkspc_res_id'_a.txt'
    cut -d \" -f 4 $wkspc_res_id'_a.txt' >>$wkspc_res_id'.txt'
    #populate request values into an array and feed that to a .csv output file
    valueline=()
    while read -r reqval; do
      requestval=$reqval','
      valueline+=("$requestval")
    done <$wkspc_res_id'.txt'
    echo ${valueline[*]} >>./output/resource_request_values.txt
    # Remove temporary resource request files
    rm $wkspc_res_id'.txt' $wkspc_res_id'_2.txt' $wkspc_res_id'_a.txt' $wkspc_res_id'_b.txt' $wkspc_res_id'_c.txt' temp.txt temp2.txt
    ((numrequests++))
  done <workspace_resource_ids.txt
  echo "Processed $numrequests Resource Requests"
}
:>./output/resource_request_values.txt
echo "Date Requested,Skill Description,Skill ID,Requester ID,Request ID,Skill Level,Workspace Resource ID,Project ID,Project Title" >./output/resource_request_values.txt
numrequests=0
filterdetails
################################################################################
# Clean Up extra spaces after comma delimiter
################################################################################
# this method uses the editor ex to globally substitute values
cleanspaces () {
  ex -s -c '%s/, /,/g|x' ./output/resource_request_values.txt
}
cleanspaces