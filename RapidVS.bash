#!/bin/bash

#Get last arg which is the site name
SITE_NAME=${@: -1}


#Default options
PORT=80

HOME="/var/www/$SITE_NAME/html"

#For true and false i'll use 0 as false and true as 1
ENABLE=0

OVERRIDE=0

ADDR=""



# Check if SiteName is provided
if [ -z "$1" ]; then
    echo "Error: SiteName not provided"
    exit 4
fi

# Function to display usage information
usage() {
    echo "Usage: $0 [-p PORT] [-h HOME] [-r ADDR] [-o] [-e] SiteName"
    exit 5
}

# Get the command line options
while getopts "p:h:r:oe" OPTION
do
        case $OPTION in
                "p")
                        #assign the port number to the PORT variable
                        PORT=$OPTARG
                        ;;
                "h")
                        #assign the home directory
                        HOME=$OPTARG
                        ;;
                "r")
                        #assign the the address to deny access to
                        ADDR="$OPTARG"
                        ;;
                "o")
                        #allow overriding directives
                        OVERRIDE=1
                        ;;
                "e")
                        #enable website
                        ENABLE=1
                        ;;
                "*")
                        # handle option error
                        printf "$OPTARG is not a valid option \n"
                        usage
                        ;;
        esac
done


#check if the given directory exists
if [[ ! -e $HOME ]]
then
        sudo mkdir -p $HOME
else
        echo "The home directory: $HOME already exists. Please retry with a different directory"
        exit 1
fi

#make the sites available with the .conf if it doesnt exist
if [[ !  -e "/etc/apache2/sites-available/$SITE_NAME.conf"  ]]
then

        sudo touch "/etc/apache2/sites-available/$SITE_NAME.conf"
        echo "Created $SITE_NAME.conf"  
        #check if we successfully created the file
        if [[  -e "/etc/apache2/sites-available/$SITE_NAME.conf"  ]]
        then

        # Check if port number conflicts with an already used service
        if [ -n "$PORT" ] && grep -q "^$PORT/tcp" /etc/services; then
                echo "Error: The port number $PORT conflicts with an already used service"
                exit 3
        fi

        #write the following to the file
        #<VirtualHost *:Port Number>
        sudo printf "<VirtualHost *:$PORT>\n" | sudo tee -a "/etc/apache2/sites-available/$SITE_NAME.conf" > /dev/null
        # ServerName site name
        sudo printf "\tServerName $SITE_NAME\n" | sudo tee -a "/etc/apache2/sites-available/$SITE_NAME.conf" > /dev/null
        # DocumentRoot directory
        sudo printf "\tDocumentRoot $HOME\n\n" | sudo tee -a "/etc/apache2/sites-available/$SITE_NAME.conf" > /dev/null
        # <Directory directory>
        sudo printf "\t<Directory $HOME>\n" | sudo tee -a "/etc/apache2/sites-available/$SITE_NAME.conf" > /dev/null

        # With the directory tag check if override option was selected
        if [[ $OVERRIDE -eq 1 ]]
        then
                # AllowOverride All
                sudo printf "\t\tAllowOverride All\n" | sudo tee -a "/etc/apache2/sites-available/$SITE_NAME.conf" > /dev/null

                # Create and configure .htaccess file
                sudo printf "# Skeleton .htaccess file\n" | sudo tee "$HOME/.htaccess" > /dev/null
                sudo printf "AuthType Basic\n" | sudo tee -a "$HOME/.htaccess" > /dev/null
                sudo printf 'AuthName "Restricted Access"\n' | sudo tee -a "$HOME/.htaccess" > /dev/null
                sudo printf "AuthUserFile /var/www/.htpasswd\n" | sudo tee -a "$HOME/.htaccess" > /dev/null
                sudo printf "Require valid-user\n" | sudo tee -a "$HOME/.htaccess" > /dev/null
        fi
        # if the string for an address was provided
        if [[ ! -z $ADDR ]]
        then
                # deny from that address given
                sudo printf "\t\tdeny from $ADDR\n" | sudo tee -a "/etc/apache2/sites-available/$SITE_NAME.conf" > /dev/null
        fi

        sudo printf "\t\tRequire all granted\n" | sudo tee -a "/etc/apache2/sites-available/$SITE_NAME.conf" > /dev/null
        # close the directory tag
        # </Directory>
        sudo printf "\t</Directory>\n" | sudo tee -a "/etc/apache2/sites-available/$SITE_NAME.conf" > /dev/null
        # close the virtual host tag
        # </VirtualHost>
        sudo printf "</VirtualHost>\n" | sudo tee -a "/etc/apache2/sites-available/$SITE_NAME.conf" > /dev/null

        echo "Configuration written to /etc/apache2/sites-available/$SITE_NAME.conf"

        fi
else

        echo "The required configuration file already exists in sites-available"
        exit 2
fi


# we can check to see ifit should be enabled
if [[ $ENABLE -eq 1 ]]
then
        sudo a2ensite $SITE_NAME.conf
        echo "$SITE_NAME is enabled"
fi

