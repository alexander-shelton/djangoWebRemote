#!/bin/bash

echo "Updating system and installing dependencies..."
sudo apt update && sudo apt upgrade -y
sudo apt install -y python3 python3-pip python3-venv git android-tools-adb

echo "Setting up Django WebRemote in /opt/djangoWebRemote..."
sudo mkdir -p /opt/djangoWebRemote
sudo chown $USER:$USER /opt/djangoWebRemote
cd /opt/djangoWebRemote

echo "Cloning Django WebRemote..."
git clone https://github.com/Alexander-N-Shelton/djangoWebRemote.git .

echo "Creating Python virtual environment..."
python3 -m venv venv
source venv/bin/activate

echo "Installing requirements..."
pip install -r requirements.txt

echo "Make and Apply Django migrations..."
python manage.py makemigrations
python manage.py migrate

echo "Adding Navigation Buttons..."
python manage.py shell < scripts/setup_navigation_buttons.py

echo "Adding Favorite Buttons..."
python manage.py shell < scripts/setup_favorites_buttons.py

echo "Collecting static files..."
python manage.py collectstatic --noinput

echo "Creating Django superuser..."
echo -e "Default administrator:\nusername = admin\npassword = password"
python manage.py shell < scripts/create_default_superuser.py

sudo tee /opt/djangoWebRemote/.env > /dev/null <<EOF
DJANGO_SECRET_KEY=$(openssl rand -hex 32)
EOF

echo "Creating systemd service..."
sudo tee /etc/systemd/system/django-web-remote.service > /dev/null <<EOF
[Unit]
Description=Web Remote Django Service
After=network.target

[Service]
User=$USER
WorkingDirectory=/opt/djangoWebRemote
EnvironmentFile=/opt/djangoWebRemote/.env
ExecStart=/opt/djangoWebRemote/venv/bin/python manage.py runserver 0.0.0.0:8000
Restart=always

[Install]
WantedBy=multi-user.target
EOF

echo "Enabling and starting the django-web-remote service..."
sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl enable --now django-web-remote

echo "Allowing traffic on port 8000 through UFW (if active)..."
sudo ufw allow 8000

echo "Setup complete. Access the remote at: http://$(hostname -I | awk '{print $1}'):8000"
