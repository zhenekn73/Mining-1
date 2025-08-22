#!/bin/bash

echo "🎯 Folding@Home Manager"
echo "========================"

# Проверяем установлен ли клиент
check_installation() {
    if [ -f "/home/user/atto/fah-client/fah-client" ]; then
        echo "✅ Клиент уже установлен"
        return 0
    else
        echo "❌ Клиент не установлен"
        return 1
    fi
}

# Функция установки клиента
install_client() {
    echo "🔄 Установка Folding@Home Client"
    echo "================================"

    # Создаем папку atto если нет
    mkdir -p /home/user/atto
    cd /home/user/atto

    echo "📦 Скачивание клиента..."
    wget -q https://download.foldingathome.org/releases/public/fah-client/debian-10-64bit/release/fah-client_8.4.9-64bit-release.tar.bz2

    if [ $? -ne 0 ]; then
        echo "❌ Ошибка скачивания!"
        exit 1
    fi

    echo "📂 Распаковка..."
    tar -xjf fah-client_8.4.9-64bit-release.tar.bz2
    mv fah-client_8.4.9-64bit-release/ fah-client/
    cd fah-client/

    # Делаем файл исполняемым
    chmod +x fah-client

    echo "🔑 Запрос данных для настройки..."
    echo "================================"

    # Запрос user (Atto address)
    read -p "Введите ваш Atto адрес (без atto://): " USER_NAME

    # Запрос passkey
    read -p "Введите ваш Passkey (32 символа): " PASSKEY

    # Запрос account token
    read -p "Введите ваш Account Token: " ACCOUNT_TOKEN

    # Запрос имени воркера (опционально)
    read -p "Введите имя воркера (опционально, Enter чтобы пропустить): " MACHINE_NAME

    echo "📝 Создание конфигурации..."
    # Создаем конфиг файл
    CONFIG_FILE="/home/user/atto/fah-client/config.xml"
    cat > $CONFIG_FILE << EOL
<config>
  <user value="$USER_NAME"/>
  <team value="1066107"/>
  <passkey value="$PASSKEY"/>
  <account-token value="$ACCOUNT_TOKEN"/>
  <cpus value="0"/>
  <on-idle value="false"/>
EOL

    # Добавляем имя машины если указано
    if [ ! -z "$MACHINE_NAME" ]; then
        echo "  <machine-name value=\"$MACHINE_NAME\"/>" >> $CONFIG_FILE
    fi

    echo "</config>" >> $CONFIG_FILE

    # Создаем скрипты управления
    echo "🚀 Создание скриптов управления..."

    # Создаем скрипт запуска в screen
    cat > /home/user/atto/start.sh << 'EOL'
#!/bin/bash
echo "🚀 Запуск Folding@Home в screen сессии..."
cd /home/user/atto/fah-client/

# Останавливаем предыдущий процесс
pkill fah-client 2>/dev/null

# Проверяем установлен ли screen
if ! command -v screen &> /dev/null; then
    echo "📦 Установка screen..."
    sudo apt update && sudo apt install -y screen
fi

# Проверяем существует ли screen сессия
if screen -list | grep -q "atto"; then
    echo "🔄 Перезапуск screen сессии atto..."
    screen -S atto -X quit
    sleep 2
fi

# Запускаем в screen сессии с именем "atto"
screen -dmS atto ./fah-client --config=config.xml

sleep 3
# Получаем PID процесса
FAH_PID=$(pgrep fah-client)
if [ ! -z "$FAH_PID" ]; then
    echo $FAH_PID > /tmp/fah.pid
    echo "✅ Запущен в screen сессии 'atto'!"
    echo "📺 PID: $FAH_PID"
    echo "🔍 Для просмотра: screen -r atto"
    echo "📋 Для детачей: Ctrl+A затем D"
else
    echo "❌ Ошибка запуска!"
fi
EOL

    # Создаем скрипт остановки
    cat > /home/user/atto/stop.sh << 'EOL'
#!/bin/bash
echo "🛑 Остановка Folding@Home..."
# Останавливаем screen сессию
screen -S atto -X quit 2>/dev/null
# Останавливаем процесс
pkill fah-client 2>/dev/null
[ -f /tmp/fah.pid ] && rm /tmp/fah.pid
echo "✅ Остановлен"
EOL

    # Создаем скрипт статуса
    cat > /home/user/atto/status.sh << 'EOL'
#!/bin/bash
echo "📊 Статус Folding@Home:"
if pgrep fah-client > /dev/null; then
    echo "✅ Запущен - PID: $(pgrep fah-client)"
    echo "💻 Screen сессия: atto"
    echo "💻 Загрузка GPU:"
    nvidia-smi | grep -E "(%|Default)" | head -5
    echo ""
    echo "🔍 Для подключения к screen: screen -r atto"
    echo "📋 Для выхода из screen: Ctrl+A затем D"
else
    echo "❌ Не запущен"
    # Проверяем есть ли screen сессия
    if screen -list | grep -q "atto"; then
        echo "⚠️  Screen сессия 'atto' существует но процесс не запущен"
    fi
fi
EOL

    # Создаем скрипт для просмотра логов в реальном времени
    cat > /home/user/atto/logs.sh << 'EOL'
#!/bin/bash
echo "📋 Просмотр логов Folding@Home:"
if pgrep fah-client > /dev/null; then
    echo "🔍 Подключаемся к screen сессии..."
    echo "ℹ️  Для выхода: Ctrl+A затем D"
    sleep 2
    screen -r atto
else
    echo "❌ Клиент не запущен"
    echo "📁 Логи в: /home/user/atto/fah-client/log.txt"
    tail -f /home/user/atto/fah-client/log.txt 2>/dev/null || echo "Файл логов не найден"
fi
EOL

    # Делаем скрипты исполняемыми
    chmod +x /home/user/atto/start.sh
    chmod +x /home/user/atto/stop.sh
    chmod +x /home/user/atto/status.sh
    chmod +x /home/user/atto/logs.sh

    echo "🎉 Установка завершена!"
}

# Функция запуска клиента
start_client() {
    echo "🚀 Запуск Folding@Home..."
    
    if [ -f "/home/user/atto/start.sh" ]; then
        /home/user/atto/start.sh
    else
        echo "❌ Скрипт запуска не найден!"
        echo "📁 Запуск вручную в screen..."
        
        # Проверяем установлен ли screen
        if ! command -v screen &> /dev/null; then
            echo "📦 Установка screen..."
            sudo apt update && sudo apt install -y screen
        fi
        
        # Останавливаем предыдущую сессию
        screen -S atto -X quit 2>/dev/null
        pkill fah-client 2>/dev/null
        
        # Запускаем в screen
        cd /home/user/atto/fah-client/
        screen -dmS atto ./fah-client --config=config.xml
        
        sleep 3
        FAH_PID=$(pgrep fah-client)
        if [ ! -z "$FAH_PID" ]; then
            echo $FAH_PID > /tmp/fah.pid
            echo "✅ Запущен в screen сессии 'atto'!"
            echo "📺 PID: $FAH_PID"
        else
            echo "❌ Ошибка запуска!"
        fi
    fi
}

# Основное меню
show_menu() {
    echo ""
    echo "🎯 Выберите действие:"
    echo "1️⃣  Установить клиент (если не установлен)"
    echo "2️⃣  Запустить клиент (если установлен)" 
    echo "3️⃣  Показать статус"
    echo "4️⃣  Остановить клиент"
    echo "5️⃣  Просмотреть логи (screen)"
    echo "6️⃣  Подключиться к screen сессии"
    echo "7️⃣  Выход"
    echo ""
    read -p "Ваш выбор (1-7): " choice

    case $choice in
        1)
            if check_installation; then
                echo "⚠️  Клиент уже установлен!"
                show_menu
            else
                install_client
                start_client
            fi
            ;;
        2)
            if check_installation; then
                start_client
            else
                echo "❌ Клиент не установлен! Сначала выполните установку."
                show_menu
            fi
            ;;
        3)
            if check_installation; then
                if [ -f "/home/user/atto/status.sh" ]; then
                    /home/user/atto/status.sh
                else
                    echo "📊 Статус:"
                    if pgrep fah-client > /dev/null; then
                        echo "✅ Запущен - PID: $(pgrep fah-client)"
                    else
                        echo "❌ Не запущен"
                    fi
                fi
            else
                echo "❌ Клиент не установлен!"
            fi
            ;;
        4)
            echo "🛑 Остановка клиента..."
            pkill fah-client 2>/dev/null
            screen -S atto -X quit 2>/dev/null
            [ -f /tmp/fah.pid ] && rm /tmp/fah.pid
            echo "✅ Остановлен"
            ;;
        5)
            if [ -f "/home/user/atto/logs.sh" ]; then
                /home/user/atto/logs.sh
            else
                echo "📋 Логи:"
                tail -f /home/user/atto/fah-client/log.txt 2>/dev/null || echo "Файл логов не найден"
            fi
            ;;
        6)
            echo "📺 Подключение к screen сессии..."
            if screen -list | grep -q "atto"; then
                screen -r atto
            else
                echo "❌ Screen сессия 'atto' не найдена"
            fi
            ;;
        7)
            echo "👋 Выход..."
            exit 0
            ;;
        *)
            echo "❌ Неверный выбор!"
            show_menu
            ;;
    esac
}

# Запуск меню
show_menu
