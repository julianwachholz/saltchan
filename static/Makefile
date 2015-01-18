
rel: bower
	browserify --bare --no-bundle-external -t coffeeify --extension=".coffee" main.coffee \
	| uglifyjs - --screw-ie8 --mangle --compress > app.min.js

dev: bower
	watchify -d -t coffeeify --extension=".coffee" -o app.js main.coffee

bower:
	bower install

# you might want to run this as root
install:
	npm install -g browserify coffeeify uglify-js

install-dev: install
	npm install -g watchify
