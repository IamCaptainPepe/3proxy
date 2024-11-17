#!/bin/bash

# Отключение IPv6
echo "Отключаем IPv6..."
sudo sysctl -w net.ipv6.conf.all.disable_ipv6=1
sudo sysctl -w net.ipv6.conf.default.disable_ipv6=1
sudo sysctl -w net.ipv6.conf.lo.disable_ipv6=1

# Проверка IP адресов
echo "Проверка IP-адресов..."
ip addr show

# Установка TTL на 65
echo "Настройка TTL на 65..."
sudo sysctl -w net.ipv4.ip_default_ttl=65

# Применение iptables для установки TTL на 65
echo "Настройка iptables для TTL..."
sudo iptables -t mangle -A POSTROUTING -j TTL --ttl-set 65

# Установка необходимых пакетов
apt update
apt install -y build-essential unzip wget iptables

# Скачивание последней версии 3proxy
wget https://github.com/3proxy/3proxy/archive/refs/tags/0.9.4.tar.gz -O 3proxy.tar.gz
tar -xzf 3proxy.tar.gz

# Проверка, создалась ли директория и переход в неё
if [ -d "3proxy-0.9.4" ]; then
  cd 3proxy-0.9.4
else
  echo "Ошибка: директория 3proxy-0.9.4 не найдена после распаковки."
  exit 1
fi

# Компиляция и установка 3proxy
make -f Makefile.Linux && make -f Makefile.Linux install

# Проверка правильного местоположения исполняемого файла
if [ -f "/bin/3proxy" ]; then
  EXEC_PATH="/bin/3proxy"
elif [ -f "/usr/local/3proxy/bin/3proxy" ]; then
  EXEC_PATH="/usr/local/3proxy/bin/3proxy"
else
  echo "Ошибка: файл 3proxy не найден после установки."
  exit 1
fi

# Создание основных директорий для конфигураций и логов
mkdir -p /usr/local/3proxy/conf /usr/local/3proxy/logs /var/log/3proxy

# Создание конфигурационного файла 3proxy
cat <<EOF > /usr/local/3proxy/conf/3proxy.cfg
# Настройки DNS
nserver 8.8.8.8
nserver 8.8.4.4

# Логирование
log /usr/local/3proxy/logs/3proxy.log D
logformat "L%y%m%d %H%M%S %p %C:%c %R:%r %Q %E %I %O %T"

# Настройки SOCKS прокси
socks -p1080
EOF

# Создание файла службы для systemd
cat <<EOF > /etc/systemd/system/3proxy.service
[Unit]
Description=3proxy Proxy Server
After=network.target

[Service]
ExecStart=$EXEC_PATH /usr/local/3proxy/conf/3proxy.cfg
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

# Перезагрузка systemd и включение и запуск службы 3proxy
systemctl daemon-reload
systemctl enable --now 3proxy

# Генерация логина и пароля для прокси
LOGIN=$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 16)
PASSWORD=$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 16)

# Вывод данных доступа
IP=$(hostname -I | awk '{print $1}')
SOCKS_PORT=1080

SOCKS_PROXY="socks5://$LOGIN:$PASSWORD@$IP:$SOCKS_PORT"

# Сохранение данных прокси в файл
echo "$SOCKS_PROXY" > /root/proxy_credentials.txt
echo "$SOCKS_PROXY" >> /var/log/proxy_install.log

# Вывод информации
echo "Доступ к прокси-серверу:"
echo "Логин: $LOGIN"
echo "Пароль: $PASSWORD"
echo "SOCKS-прокси доступен по адресу: $SOCKS_PROXY"

# Проверка TTL
echo "Проверка TTL..."
ping -c 4 google.com
