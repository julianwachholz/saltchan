
DEST=../static


rel: deps
	mkdir -p $(DEST)
	browserify --bare --no-bundle-external -t coffeeify --extension=".coffee" main.coffee \
	| uglifyjs - --screw-ie8 --mangle --compress > $(DEST)/app.min.js

dev: deps
	watchify -d -t coffeeify --extension=".coffee" -o $(DEST)/app.js main.coffee

deps:
	bower install tweetnacl#~0.13.0
	bower install reqwest#~1.1.5
	npm install coffeeify

# you might want to run this as root
install:
	npm install -g browserify coffeeify uglify-js

install-dev: install
	npm install -g watchify
