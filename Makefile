
# saltchan

default: files
	pip install -r requirements.txt
	make -C assets

files:
	# file directories are not created by flask
	mkdir -p files/b files/g
