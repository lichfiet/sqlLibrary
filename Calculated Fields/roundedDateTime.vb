Instructions:

Replace the "XXXXXXXX" with the $f{columnName} of your date/time column




-- Copy Date / Time Seconds // Name Field "dateTimeSeconds" --

Copy((XXXXXXXX), 18, 2)

-- Copy Date / Time MOututes // Name field "dateTimeMinutes" --

Copy((XXXXXXXX), 15, 2)

-- Copy Date / Time Hours // Name field "dateTimeHours" --

Copy((XXXXXXXX), 12, 2)

-- Round mOututes based on seconds // Name field "doRoundDateTimeMinutes"

If $f{dateTimeSeconds} = "00" 
Then "0"
Else If $f{dateTimeSeconds} = "01" 
Then "0"
Else If $f{dateTimeSeconds} = "02" 
Then "0"
Else If $f{dateTimeSeconds} = "03" 
Then "0"
Else If $f{dateTimeSeconds} = "04" 
Then "0"
Else If $f{dateTimeSeconds} = "05" 
Then "0"
Else If $f{dateTimeSeconds} = "06" 
Then "0"
Else If $f{dateTimeSeconds} = "07" 
Then "0"
Else If $f{dateTimeSeconds} = "08" 
Then "0"
Else If $f{dateTimeSeconds} = "09" 
Then "0"
Else If $f{dateTimeSeconds} = "10" 
Then "0"
Else If $f{dateTimeSeconds} = "11" 
Then "0"
Else If $f{dateTimeSeconds} = "12" 
Then "0"
Else If $f{dateTimeSeconds} = "13" 
Then "0"
Else If $f{dateTimeSeconds} = "14" 
Then "0"
Else If $f{dateTimeSeconds} = "15" 
Then "0"
Else If $f{dateTimeSeconds} = "16" 
Then "0"
Else If $f{dateTimeSeconds} = "17" 
Then "0"
Else If $f{dateTimeSeconds} = "18" 
Then "0"
Else If $f{dateTimeSeconds} = "19" 
Then "0"
Else If $f{dateTimeSeconds} = "20" 
Then "0"
Else If $f{dateTimeSeconds} = "21" 
Then "0"
Else If $f{dateTimeSeconds} = "22" 
Then "0"
Else If $f{dateTimeSeconds} = "23" 
Then "0"
Else If $f{dateTimeSeconds} = "24" 
Then "0"
Else If $f{dateTimeSeconds} = "25" 
Then "0"
Else If $f{dateTimeSeconds} = "26" 
Then "0"
Else If $f{dateTimeSeconds} = "27" 
Then "0"
Else If $f{dateTimeSeconds} = "28" 
Then "0"
Else If $f{dateTimeSeconds} = "29" 
Then "0"
Else "1"
End
End
End
End
End
End
End
End
End
End
End
End
End
End
End
End
End
End
End
End
End
End
End
End
End
End
End
End
End
End

-- Return rounded minutes // Name field "roundedDateTimeMinutes"

If $f{dateTimeMinutes} = "00" AND $f{doRoundDateTimeMinutes} = "1"
Then "01"
Else If $f{dateTimeMinutes} = "01" AND $f{doRoundDateTimeMinutes} = "1"
Then "02"
Else If $f{dateTimeMinutes} = "02" AND $f{doRoundDateTimeMinutes} = "1"
Then "03"
Else If $f{dateTimeMinutes} = "03" AND $f{doRoundDateTimeMinutes} = "1"
Then "04"
Else  If $f{dateTimeMinutes} = "04" AND $f{doRoundDateTimeMinutes} = "1"
Then "05"
Else  If $f{dateTimeMinutes} = "05" AND $f{doRoundDateTimeMinutes} = "1"
Then "06"
Else  If $f{dateTimeMinutes} = "06" AND $f{doRoundDateTimeMinutes} = "1"
Then "07"
Else  If $f{dateTimeMinutes} = "07" AND $f{doRoundDateTimeMinutes} = "1"
Then "08"
Else  If $f{dateTimeMinutes} = "08" AND $f{doRoundDateTimeMinutes} = "1"
Then "09"
Else  If $f{dateTimeMinutes} = "09" AND $f{doRoundDateTimeMinutes} = "1"
Then "10"
Else  If $f{dateTimeMinutes} = "10" AND $f{doRoundDateTimeMinutes} = "1"
Then "11"
Else  If $f{dateTimeMinutes} = "11" AND $f{doRoundDateTimeMinutes} = "1"
Then "12"
Else  If $f{dateTimeMinutes} = "12" AND $f{doRoundDateTimeMinutes} = "1"
Then "13"
Else  If $f{dateTimeMinutes} = "13" AND $f{doRoundDateTimeMinutes} = "1"
Then "14"
Else  If $f{dateTimeMinutes} = "14" AND $f{doRoundDateTimeMinutes} = "1"
Then "15"
Else  If $f{dateTimeMinutes} = "15" AND $f{doRoundDateTimeMinutes} = "1"
Then "16"
Else  If $f{dateTimeMinutes} = "16" AND $f{doRoundDateTimeMinutes} = "1"
Then "17"
Else  If $f{dateTimeMinutes} = "17" AND $f{doRoundDateTimeMinutes} = "1"
Then "18"
Else  If $f{dateTimeMinutes} = "18" AND $f{doRoundDateTimeMinutes} = "1"
Then "19"
Else  If $f{dateTimeMinutes} = "19" AND $f{doRoundDateTimeMinutes} = "1"
Then "20"
Else  If $f{dateTimeMinutes} = "20" AND $f{doRoundDateTimeMinutes} = "1"
Then "21"
Else  If $f{dateTimeMinutes} = "21" AND $f{doRoundDateTimeMinutes} = "1"
Then "22"
Else  If $f{dateTimeMinutes} = "22" AND $f{doRoundDateTimeMinutes} = "1"
Then "23"
Else  If $f{dateTimeMinutes} = "23" AND $f{doRoundDateTimeMinutes} = "1"
Then "24"
Else  If $f{dateTimeMinutes} = "24" AND $f{doRoundDateTimeMinutes} = "1"
Then "25"
Else  If $f{dateTimeMinutes} = "25" AND $f{doRoundDateTimeMinutes} = "1"
Then "26"
Else  If $f{dateTimeMinutes} = "26" AND $f{doRoundDateTimeMinutes} = "1"
Then "27"
Else  If $f{dateTimeMinutes} = "27" AND $f{doRoundDateTimeMinutes} = "1"
Then "28"
Else  If $f{dateTimeMinutes} = "28" AND $f{doRoundDateTimeMinutes} = "1"
Then "29"
Else  If $f{dateTimeMinutes} = "29" AND $f{doRoundDateTimeMinutes} = "1"
Then "30"
Else  If $f{dateTimeMinutes} = "30" AND $f{doRoundDateTimeMinutes} = "1"
Then "31"
Else  If $f{dateTimeMinutes} = "31" AND $f{doRoundDateTimeMinutes} = "1"
Then "32"
Else  If $f{dateTimeMinutes} = "32" AND $f{doRoundDateTimeMinutes} = "1"
Then "33"
Else  If $f{dateTimeMinutes} = "33" AND $f{doRoundDateTimeMinutes} = "1"
Then "34"
Else  If $f{dateTimeMinutes} = "34" AND $f{doRoundDateTimeMinutes} = "1"
Then "35"
Else  If $f{dateTimeMinutes} = "35" AND $f{doRoundDateTimeMinutes} = "1"
Then "36"
Else  If $f{dateTimeMinutes} = "36" AND $f{doRoundDateTimeMinutes} = "1"
Then "37"
Else  If $f{dateTimeMinutes} = "37" AND $f{doRoundDateTimeMinutes} = "1"
Then "38"
Else  If $f{dateTimeMinutes} = "38" AND $f{doRoundDateTimeMinutes} = "1"
Then "39"
Else  If $f{dateTimeMinutes} = "39" AND $f{doRoundDateTimeMinutes} = "1"
Then "40"
Else  If $f{dateTimeMinutes} = "40" AND $f{doRoundDateTimeMinutes} = "1"
Then "41"
Else  If $f{dateTimeMinutes} = "41" AND $f{doRoundDateTimeMinutes} = "1"
Then "42"
Else  If $f{dateTimeMinutes} = "42" AND $f{doRoundDateTimeMinutes} = "1"
Then "43"
Else  If $f{dateTimeMinutes} = "43" AND $f{doRoundDateTimeMinutes} = "1"
Then "44"
Else  If $f{dateTimeMinutes} = "44" AND $f{doRoundDateTimeMinutes} = "1"
Then "45"
Else  If $f{dateTimeMinutes} = "45" AND $f{doRoundDateTimeMinutes} = "1"
Then "46"
Else  If $f{dateTimeMinutes} = "46" AND $f{doRoundDateTimeMinutes} = "1"
Then "47"
Else  If $f{dateTimeMinutes} = "47" AND $f{doRoundDateTimeMinutes} = "1"
Then "48"
Else  If $f{dateTimeMinutes} =  "48" AND $f{doRoundDateTimeMinutes} = "1"
Then "49"
Else  If $f{dateTimeMinutes} = "49" AND $f{doRoundDateTimeMinutes} = "1"
Then "50"
Else  If $f{dateTimeMinutes} = "50" AND $f{doRoundDateTimeMinutes} = "1"
Then "51"
Else  If $f{dateTimeMinutes} = "51" AND $f{doRoundDateTimeMinutes} = "1"
Then "52"
Else  If $f{dateTimeMinutes} = "52" AND $f{doRoundDateTimeMinutes} = "1"
Then "53"
Else  If $f{dateTimeMinutes} = "53" AND $f{doRoundDateTimeMinutes} = "1"
Then "54"
Else  If $f{dateTimeMinutes} = "54" AND $f{doRoundDateTimeMinutes} = "1"
Then "55"
Else  If $f{dateTimeMinutes} = "55" AND $f{doRoundDateTimeMinutes} = "1"
Then "56"
Else  If $f{dateTimeMinutes} = "56" AND $f{doRoundDateTimeMinutes} = "1"
Then "57"
Else  If $f{dateTimeMinutes} = "57" AND $f{doRoundDateTimeMinutes} = "1"
Then "58"
Else  If $f{dateTimeMinutes} = "58" AND $f{doRoundDateTimeMinutes} = "1"
Then "59"
Else  If $f{dateTimeMinutes} = "59" AND $f{doRoundDateTimeMinutes} = "1"
Then "00"
Else If $f{doRoundDateTimeMinutes} = "0" AND $f{dateTimeMinutes} = "00"
Then "00"
Else $f{dateTimeMinutes}
End
End
End
End
End
End
End
End
End
End
End
End
End
End
End
End
End
End
End
End
End
End
End
End
End
End
End
End
End
End
End
End
End
End
End
End
End
End
End
End
End
End
End
End
End
End
End
End
End
End
End
End
End
End
End
End
End
End
End
End
End

-- Do round date / time hour? Field name: "doRoundDateTimeHours" --

If $f{dateTimeMinutes} = "59"
Then "1"
Else "0"
End

-- Rounded date / time hours Field Name: "roundedDateTimeHours"-- 

If $f{dateTimeHours} = "01" AND $f{doRoundDateTimeHours} = "1"
Then "02"
Else If $f{dateTimeHours} = "02" AND $f{doRoundDateTimeHours} = "1"
Then "03"
Else If $f{dateTimeHours} = "03" AND $f{doRoundDateTimeHours} = "1"
Then "04"
Else If $f{dateTimeHours} = "04" AND $f{doRoundDateTimeHours} = "1"
Then "05"
Else If $f{dateTimeHours} = "05" AND $f{doRoundDateTimeHours} = "1"
Then "06"
Else If $f{dateTimeHours} = "06" AND $f{doRoundDateTimeHours} = "1"
Then "07"
Else If $f{dateTimeHours} = "07" AND $f{doRoundDateTimeHours} = "1"
Then "08"
Else If $f{dateTimeHours} = "08" AND $f{doRoundDateTimeHours} = "1"
Then "09"
Else If $f{dateTimeHours} = "09" AND $f{doRoundDateTimeHours} = "1"
Then "10"
Else If $f{dateTimeHours} = "10" AND $f{doRoundDateTimeHours} = "1"
Then "11"
Else If $f{dateTimeHours} = "11" AND $f{doRoundDateTimeHours} = "1"
Then "12"
Else If $f{dateTimeHours} = "12" AND $f{doRoundDateTimeHours} = "1"
Then "01"
Else If $f{doRoundDateTimeHours} = "0"
Then $f{dateTimeHours}
Else $f{dateTimeHours}
End
End
End
End
End
End
End
End
End
End
End
End
End


-- am or pm based on rounded hour Field Name: "dateTimeAmOrPm" -- 

If Copy(DateTimeToStr($f{XXXXXXXX}), 21, 2) = "AM" AND $f{roundedDateTimeHours} = "01" AND $f{dateTimeHours} = "12"
Then "PM"
Else If Copy(DateTimeToStr($f{XXXXXXXX}), 21, 2) = "PM" AND $f{roundedDateTimeHours} = "01" AND $f{dateTimeHours} = "12"
Then "AM"
Else Copy(DateTimeToStr($f{XXXXXXXX}), 21, 2)
End
End


-- complete date/time Field Name: "roundedDateTime" --

Copy(DateTimeToStr($f{XXXXXXXX}), 0, 12) + $f{roundedDateTimeHours} + ":" + $f{roundedDateTimeMinutes} + $f{clockInAmOrPm}
