#!/bin/bash

echo ""
echo -e "\033[33mWordPress 一键安装脚本\033[0m"
echo -e "\033[33m欢迎访问我的blog https://newxin.net  \033[0m"
echo -e "\033[33m欢迎访问我的YouTube频道 https://bit.ly/2R5338U  \033[0m"
echo ""

if [ $UID -ne 0 ]; then
  echo -e "\033[41;37m需要root身份。 \033[0m"
  echo -e "\033[41;37m请使用 \"sudo bash $0\" \033[0m"
  exit 3
fi

echo -e "\033[33m请输入你要设定的MySQL的root密码 \033[0m"
read pass_mysql
if [[ ! -n $pass_mysql ]]; then
  echo -e "\033[41;37mMySQL的root密码必须输入 \033[0m"
  exit 2
fi

echo ""
echo -e "\033[33m输入你的域名 \033[0m"
echo -e "\033[33m! 确认已经添加了A类名称。\033[0m"
echo -e "\033[33m! 不要在域名前添加 'www.'。\033[0m"
read domain
if [[ ! -n $domain ]]; then
  echo -e "\033[41;37m域名必须填写 \033[0m"
  exit 2
fi

echo ""
echo -e "\033[33m输入你的邮箱 \033[0m"
echo -e "\033[33m! 申请 Let's Encrypt SSL 的必需使用邮箱。 \033[0m"
read email
if [[ ! -n $email ]]; then
  echo -e "\033[41;37m邮箱必须输入。\033[0m"
  exit 2
fi

echo ""
echo "配置中..."
echo $domain > /etc/hostname >/dev/null 2>&1
hostname -F /etc/hostname >/dev/null 2>&1

echo "更新中..."
apt-get update >/dev/null 2>&1

echo "安裝 NGINX 和 php-7.2..."
apt-get -y install wget unzip nginx php7.2-fpm php7.2-mysql php7.2-gd php7.2-mbstring software-properties-common >/dev/null 2>&1

echo "验证安装..."
if [[ -d /etc/nginx/sites-available ]]; then
  echo "找到 /etc/nginx/"
else
  echo -e "\033[41;37m在安裝 NGINX 時出現問題。 \033[0m"
  echo -e "\033[41;37m請檢查系統配置需求，或聯繫作者。\033[0m"
  exit 1
fi
if [[ -d /etc/php/7.0/mods-available ]]; then
  echo "找到 /etc/php/7.0/"
else
  echo -e "\033[41;37m在安裝 php-7.2 時出現問題。\033[0m"
  echo -e "\033[41;37m請檢查系統配置需求，或聯繫作者。\033[0m"
  exit 1
fi

echo "以指定的根用戶密碼安裝 MySQL..."
prompt_1="mysql-server mysql-server/root_password password $pass_mysql"
prompt_2="mysql-server mysql-server/root_password_again password $pass_mysql"
debconf-set-selections <<< $prompt_1
debconf-set-selections <<< $prompt_2
apt-get -y install mysql-server >/dev/null 2>&1

echo "安裝 Certbot..."
if [ ! -z "`cat /etc/issue | grep bian`" ];then
  apt-get install -y certbot >/dev/null 2>&1
elif [ ! -z "`cat /etc/issue | grep Ubuntu`" ];then
  add-apt-repository -y ppa:certbot/certbot >/dev/null 2>&1
  apt-get update >/dev/null 2>&1
  apt-get install -y python-certbot-nginx >/dev/null 2>&1
else
  echo -e "\033[41;37m您的Linux發行版不受支援。\033[0m"
  exit 4
fi

echo "申請 Let's Encrypt SSL 證書..."
sed -i "s/server_name _/server_name $domain/g" /etc/nginx/sites-available/default >/dev/null 2>&1
service nginx restart >/dev/null 2>&1
certbot -d $domain -m $email -n --nginx --agree-tos certonly >/dev/null 2>&1

echo "驗證申請結果..."
if [[ -f /etc/letsencrypt/live/$domain/fullchain.pem ]]; then
  echo "找到 /etc/letsencrypt/live/$domain/fullchain.pem"
else
  echo -e "\033[41;37m申請SSL證書時出現問題。 \033[0m"
  echo -e "\033[41;37m確認網域名稱的A記錄指向該主機的IP位址。\033[0m"
  exit 5
fi
if [[ -f /etc/letsencrypt/live/$domain/privkey.pem ]]; then
  echo "找到 /etc/letsencrypt/live/$domain/privkey.pem"
else
  echo -e "\033[41;37m申請SSL證書時出現問題。 \033[0m"
  echo -e "\033[41;37m確認網域名稱的A記錄指向該主機的IP位址。\033[0m"
  exit 5
fi

echo "配置 NGINX..."
wget http://cdn.ralf.ren/sp/assets/wp_lnmp/wordpress.conf -O /etc/nginx/wordpress.conf >/dev/null 2>&1
rm -f /etc/nginx/sites-available/default
wget http://cdn.ralf.ren/sp/assets/wp_lnmp/default_https -O /etc/nginx/sites-available/default >/dev/null 2>&1
sed -i "s/domain.name/$domain/g" /etc/nginx/sites-available/default >/dev/null 2>&1
wget http://cdn.ralf.ren/sp/assets/wp_lnmp/wordpress.sql >/dev/null 2>&1


echo "驗證文件..."
if [[ -f /etc/nginx/wordpress.conf ]]; then
  echo "找到 /etc/nginx/wordpress.conf"
else
  echo -e "\033[41;37m下載必需文件時出現問題。\033[0m"
  echo -e "\033[41;37m請檢查網際網路連線。\033[0m"
  exit 1
fi
if [[ -f /etc/nginx/sites-available/default ]]; then
  echo "找到 /etc/nginx/sites-available/default"
else
  echo -e "\033[41;37m下載必需文件時出現問題。\033[0m"
  echo -e "\033[41;37m請檢查網際網路連線。\033[0m"
  exit 1
fi
if [[ -f wordpress.sql ]]; then
  echo "找到 wordpress.sql"
else
  echo -e "\033[41;37m下載必需文件時出現問題。\033[0m"
  echo -e "\033[41;37m請檢查網際網路連線。\033[0m"
  exit 1
fi

echo "創建 MySQL 資料庫..."
pass_db=`openssl rand 6 -base64`
sed -i "s/lombax/$pass_db/g" wordpress.sql >/dev/null 2>&1
mysql -uroot -p$pass_mysql < wordpress.sql >/dev/null 2>&1


echo "下載 WordPress... "
rm -rf /var/www/* >/dev/null 2>&1
wget https://wordpress.org/latest.zip -O /var/www/latest.zip >/dev/null 2>&1

echo "驗證文件..."
if [[ -f /var/www/latest.zip ]]; then
  echo "找到 /var/www/latest.zip"
else
  echo -e "\033[41;37m下載WordPress時出現問題。\033[0m"
  echo -e "\033[41;37m請檢查網際網路連線。\033[0m"
  exit 1
fi

echo "安裝 WordPress..."
unzip /var/www/latest.zip -d /var/www/ >/dev/null 2>&1
mv /var/www/wordpress/* /var/www >/dev/null 2>&1
rm -rf /var/www/wordpress >/dev/null 2>&1
rm -f /var/www/latest.zip >/dev/null 2>&1
chmod 755 /var/www >/dev/null 2>&1
find /var/www -type d -exec chmod 755 {} \; >/dev/null 2>&1
find /var/www -type f -exec chmod 644 {} \; >/dev/null 2>&1
chown -R www-data:www-data /var/www >/dev/null 2>&1

echo "完成安裝..."
service php7.2-fpm restart >/dev/null 2>&1
service nginx restart >/dev/null 2>&1

echo "稍加清理..."
rm -f wordpress.sql >/dev/null 2>&1

echo "完成。"
echo ""
echo -en "\033[33m立即打开 \033[0m"
echo -en "\033[44;37mhttp://$domain\033[0m"
echo -e "\033[33m 完成 WordPress 初始配置。 \033[0m"
echo ""
echo -e "\033[33m记下下列数据 \033[0m"
echo -en "\033[33m数据库名称:\033[0m"
echo -e "\033[44;37mwordpress\033[0m"
echo -en "\033[33m数据库用户名:\033[0m"
echo -e "\033[44;37mwordpress\033[0m"
echo -en "\033[33mwordpress数据库密码:\033[0m"
echo -e "\033[44;37m$pass_db\033[0m"
echo -en "\033[33m数据库位置:\033[0m"
echo -e "\033[44;37mlocalhost\033[0m"