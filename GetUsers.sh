#!/bin/bash
################################################################################
# Author - Russell Brown
# Contact Email: rbrown@cohesity.com
# Contact Phone: +1 747.241.7117
# Creation Date: 26 July 2022
# Last Updated: 2 December 2022
# Mavenlink API call to collect all User Names and User IDs for an account
################################################################################
# Please create a directory called "output" in the local directory where you run this script
iofilehandle=users
# You will need to generate your Mavenlink Token and put it into a file called token.txt
authtoken=$(<token.txt)
curl -H 'Authorization: Bearer '$authtoken \
   "https://api.mavenlink.com/api/v1/users.json?on_my_account=true&per_page=8000" \
   >$iofilehandle.txt
################################################################################
# CONVERT output to json file
/usr/bin/python3 -m json.tool $iofilehandle'.txt' >$iofilehandle'.json'
################################################################################
rm './'iofilehandle'.txt'
# headers for final output file
echo "UserID|Full Name|" >./output/selected_user_values.txt
# Take the output file and extract the user ids
grep -A 2 '\"key\"\: \"users\"\,' './'$iofilehandle'.json' | grep '\"id\"' >'./'$iofilehandle'.txt'
# Cut out the 4th element of an array delimited by double quotes
cut -d \" -f 4 './'$iofilehandle'.txt' >'./output/'$iofilehandle'_ids.txt'
# define array for capturing user id and full name
# names()
while IFS= read -r line; do
 echo "User ID " $line
 # Generate a temp file with the attributes for a specific project ID
 grep -A 25 "\""$line"\": {" './'$iofilehandle'.json' | grep '\"id\"\:' >'./'$iofilehandle'.txt'
 grep -A 25 "\""$line"\": {" './'$iofilehandle'.json' | grep '\"full_name\"\:' >>'./'$iofilehandle'.txt'
 cut -d \" -f 4 './'$iofilehandle'.txt' >'./output/'$iofilehandle'_ids2.txt'
 # Read in values from output file to populate array and add a pipe character as a delimiter
 entryvalues=()
 while IFS= read -r entryval; do
 # attempting to insert a pipe character after every line / variable
   entryval=$entryval'|'
   entryvalues+=("$entryval")
 done <'./output/'$iofilehandle'_ids2.txt'
# Output to Summary File for All Time Entries
 echo ${entryvalues[*]} >>./output/selected_user_values.txt
# Output to Screen - if necessary for troubleshooting
# echo ${entryvalues[*]}
done <'./output/'$iofilehandle'_ids.txt'
################################################################################
# CLEANUP Files
rm ./$iofilehandle'.txt'
rm './output/'$iofilehandle'_ids.txt'
rm './output/'$iofilehandle'_ids2.txt'