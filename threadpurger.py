#!/usr/bin/env python

from redis import StrictRedis
import config
import bbs


def main(r):
    pass


if __name__ == '__main__':
    r = StrictRedis(host='localhost', port=6379, db=1)
    main(r)
