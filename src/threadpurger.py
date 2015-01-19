#!/usr/bin/env python
"""
Sweep old and stale threads.

"""
import config
import bbs


def main(r):
    for board in config.BOARDS.keys():
        for thread_id in bbs.get_stale_threads(r, board):
            bbs.purge_thread(r, board, thread_id)


if __name__ == '__main__':
    r = config.get_redis()
    main(r)
