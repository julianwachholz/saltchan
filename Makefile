
# saltchan

default: deps
	$(MAKE) -C assets

dev: deps
	$(MAKE) -C assets dev

deps:
	pip install -r requirements.txt

files:
	# file directories are not created by flask
	mkdir -p files/b files/g

install: files
	$(MAKE) -C assets install

install-dev: files
	$(MAKE) -C assets install-dev
