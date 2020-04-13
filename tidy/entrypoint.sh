#!/usr/bin/env sh
populate_database() {                                                           
    # populate the postgres database with the backup data                         
    echo -e "Populating the database (this may take awhile)"                      
    # sleep needed to prevent error of database not being reachable               
    RETRIES_REMAINING=${MAX_RETRIES}                                              
    until docker exec db psql -d postgres -c \                                  
       "select count(*) from scraping.raw_data;"                                 
      do                                                                          
        sleep 1                                                                   
        RETRIES_REMAINING=$((RETRIES_REMAINING - 1))                              
        if [ "${RETRIES_REMAINING}" -lt 1 ]; then                                 
          echo -e "\e[31m GIVING UP ON DATABASE CONNECTION \e[39m"                
        fi                                                                        
        echo -e "\e[33m retrying \e[39m database, retry ${RETRIES_REMAINING}"        
      done                                                                        
    if [ "$?" -eq "0" ]; then                                                     
      echo -e "Database \e[32msuccessfully\e[39m populated."                      
    else                                                                          
      stop_all                                                                    
    fi                                                                            
}      
populate_database
python3 /tmp/bin/scheduler.py
tail -f /dev/null
