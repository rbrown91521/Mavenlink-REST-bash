#!/bin/bash
################################################################################
# Author - Russell Brown
# Contact Email: rbrown@cohesity.com
# Contact Phone: +1 747.241.7117
# Creation Date: 26 July 2022
# Last Updated: 23 June 2023
# Mavenlink API call to collect all User Names and User IDs for an account
################################################################################
# Please create a directory called "output" in the local directory where you run this script
iofilehandle=users
finaloutputfile='./output/selected_user_values.txt'
# You will need to generate your Mavenlink Token and put it into a file called token.txt
authtoken=$(<token.txt)
# REST API Call to get the user details from Mavenlink
curl -H 'Authorization: Bearer '$authtoken \
   "https://api.mavenlink.com/api/v1/users.json?on_my_account=true&per_page=8000" \
   >$iofilehandle'2.txt'
################################################################################
# CONVERT output to json file
# Many Mavenlink REST API calls return header info with the payload on the last line
tail -1 $iofilehandle'2.txt' >$iofilehandle'.txt'
/usr/bin/python3 -m json.tool $iofilehandle'.txt' >$iofilehandle'.json'
rm $iofilehandle'.txt' $iofilehandle'2.txt'
################################################################################
# headers for final output file
echo "UserID|Full Name|Title|Email" >$finaloutputfile
getuserids () {
  # Take the REST API output file and extract the user ids
  grep -A 1 -e "\"key\":" $iofilehandle'.json' | grep '\"id\"' >$iofilehandle'.txt'
  # Cut out the 4th element of an array delimited by double quotes
  cut -d \" -f 4 $iofilehandle'.txt' >$iofilehandle'_ids.txt'
  # CLEANUP Temp File
  rm './'$iofilehandle'.txt'
}
getuserids
getuserattributes () {
  # Count the total number of users
  numberofusers=0
  while IFS= read -r userid; do
    echo $userid >$iofilehandle'_ids2.txt'
    # Generate a temp file with the attributes for a specific user ID
    grep -A 24 -e "\"$userid\":" $iofilehandle'.json' | grep -e "\"full_name\":">>$userid'.txt'
    grep -A 24 -e "\"$userid\":" $iofilehandle'.json' | grep -e "\"headline\":">>$userid'.txt'
    grep -A 24 -e "\"$userid\":" $iofilehandle'.json' | grep -e "\"email_address\":">>$userid'.txt'
    cut -d \" -f 4 $userid'.txt' >>$iofilehandle'_ids2.txt'
    # Read in values from output file to populate array and add a pipe character as a delimiter
    entryvalues=()
    while IFS= read -r entryval; do
      # attempting to insert a pipe character after every line / variable
      entryval=$entryval'|'
      entryvalues+=("$entryval")
    done <$iofilehandle'_ids2.txt'
    # Output to Summary File for All Time Entries
    echo ${entryvalues[*]} >>$finaloutputfile
    # Increment Count for the number of entries
    ((numberofusers++))
    # Output iteration and user name to screen to show progress
    echo ${entryvalues[1]} | rev | cut -c 2- | rev >currentuser.txt
    currentuser=$(<currentuser.txt)
    echo "$numberofusers $currentuser"
    # CLEANUP user id and user name temp files
    rm $userid'.txt' currentuser.txt
  done <$iofilehandle'_ids.txt'
  echo 'Wrote details for '$numberofusers' User Accounts to the file '$finaloutputfile
  ################################################################################
  # CLEANUP Files
  rm $iofilehandle'_ids.txt' $iofilehandle'_ids2.txt'
}
getuserattributes
################################################################################
# Clean Up extra spaces after pipe delimiter using the ex editor
cleanspaces () {
  ex -s -c '%s/| /|/g|x' $finaloutputfile
}
cleanspaces
