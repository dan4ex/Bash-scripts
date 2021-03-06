#!/bin/bash
PROJECT_NAME="demo"
INSTALL_PROJECT="symfony/symfony-demo"
SYMLINK="latest"
RELEASE=$1

if [[ -z "$RELEASE" ]]
then
   echo "Run script with args"
   echo "Exapmle usage: ./symlink_deploy.sh <your_version>"
   exit 1
fi

#Install package
cd ~/
apt update
apt install -y wget nginx php7.2-cli php7.2-common php7.2-fpm php7.2-cgi php7.2-sqlite php7.2-mbstring php7.2-zip php7.2-xml

#Install Symphony
if [[ $(ls -la /usr/bin | grep symfony) ]]
then
  echo "Symfony is already installer"
else
   wget https://get.symfony.com/cli/installer -O - | bash
   mv ~/.symfony/bin/symfony /usr/bin/symfony
fi

#Install Composer
if [[ $(ls -la /usr/bin | grep composer) ]]
then
  echo "Composer is already installer"
else
  php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
  php -r "if (hash_file('sha384', 'composer-setup.php') === 'e5325b19b381bfd88ce90a5ddb7823406b2a38cff6bb704b0acc289a09c8128d4a8ce2bbafcd1fcbdc38666422fe2806') { echo 'Installer verified'; } else { echo 'Installer corrupt'; unlink('composer-setup.php'); } echo PHP_EOL;"
  php composer-setup.php
  php -r "unlink('composer-setup.php');"
  mv composer.phar /usr/bin/composer
fi

#Symfony create project
mkdir -p /var/www/$RELEASE && cd /var/www/$RELEASE
composer create-project $INSTALL_PROJECT $PROJECT_NAME

#Configure nginx
if [[ $(find /etc/nginx/sites-available/ -type f -name "default") ]]
then
  rm -f /etc/nginx/sites-available/default
  rm -f /etc/nginx/sites-enabled/default
fi
if [[ $(find /etc/nginx/sites-available/ -type f -name $PROJECT_NAME) ]]
then
  echo "nginx is already configure"
else
  tee /etc/nginx/sites-available/$PROJECT_NAME <<EOF
server {
          listen 80 default_server;
          listen [::]:80 default_server;

          root /var/www/$SYMLINK;

          server_name _;

          location / {
                  try_files \$uri /index.php\$is_args\$args;
          }

          location ~ ^/index\.php(/|\$) {
                  fastcgi_pass unix:/var/run/php/php7.2-fpm.sock;
                  fastcgi_split_path_info ^(.+\.php)(/.*)\$;
                  include fastcgi_params;
                  fastcgi_param SCRIPT_FILENAME \$realpath_root\$fastcgi_script_name;
                  fastcgi_param DOCUMENT_ROOT \$realpath_root;
          }
          location ~ \.php\$ {
          return 404;
          }
  }
EOF
  ln -s /etc/nginx/sites-available/$PROJECT_NAME /etc/nginx/sites-enabled/$PROJECT_NAME
  systemctl restart nginx
fi

if [[ $? -eq 0 ]]
then
  echo "#################################"
  echo "Nginx is successfull restarting:)"
else
  echo "##################################"
  echo "Nginx restart is fail:("
  nginx -t
  exit 1
fi

#Change owner
echo "##############################"
echo "CHANGE OWNER TO SITE DIRECTORY"
chown -R www-data:www-data /var/www/$RELEASE/$PROJECT_NAME

#Symlink deployment
echo "##########################"
echo "CREATE SYMLINK DEPLOYMENT"
ln -sfn /var/www/$RELEASE/$PROJECT_NAME/public /var/www/$SYMLINK
