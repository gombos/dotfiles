mkdir -p /tmp/dupe
git clone https://github.com/hsoft/dupeguru.git /tmp/dupe
sudo apt update -y
sudo apt install -y -q --no-install-recommends python3-pyqt5 pyqt5-dev-tools gettext python3-venv python3-dev python3-sphinx python3-setuptools
cd /tmp/dupe && make
