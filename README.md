# saltchan

An easy to use almost-anonymous (pseudonymous) BBS with piece of cake publickey encryption.

## Installation

Follow these steps to create your local running instance:

0. Install Python 3 and Redis-Server
1. Create a virtualenv with Python 3 and activate it
2. `sudo make install-dev`
3. `make dev` (This will watch for changes, abort job or send to background)
4. `src/chan.py`


## Configuration

See `src/config.py` for configuration options.

To run this in a production environment, adjust as needed. Volatile settings
can be configured with environment variables.


## License

saltchan is licensed under BSD. See `LICENSE` file for further information.
