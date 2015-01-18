
# pgpchan

default:
	source /opt/pgpchan/env/bin/activate
	pip install -r requirements.txt
	make -C static
