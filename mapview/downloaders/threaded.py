from os.path import exists
from kivy.clock import Clock
from random import choice
import traceback
from time import time
from mapview.downloader import Downloader
from concurrent.futures import ThreadPoolExecutor, TimeoutError, as_completed
import requests

class ThreadedDownloader(Downloader):
    def setup(self):
        self.executor = ThreadPoolExecutor(max_workers=self.max_workers)
        self._futures = []
        Clock.schedule_interval(self._check_executor, 1 / 60.)

    def submit(self, f, *args, **kwargs):
        future = self.executor.submit(f, *args, **kwargs)
        self._futures.append(future)

    def download_tile(self, tile):
        future = self.executor.submit(self._load_tile, tile)
        self._futures.append(future)

    def download(self, url, callback, **kwargs):
        future = self.executor.submit(self._download_url, url, callback, kwargs)
        self._futures.append(future)

    def _download_url(self, url, callback, kwargs):
        r = requests.get(url, **kwargs)
        return callback, (url, r, )

    def _load_tile(self, tile):
        if tile.state == "done":
            return
        cache_fn = tile.cache_fn
        if exists(cache_fn):
            return tile.set_source, (cache_fn, )
        tile_y = tile.map_source.get_row_count(tile.zoom) - tile.tile_y - 1
        uri = tile.map_source.url.format(z=tile.zoom, x=tile.tile_x, y=tile_y,
                              s=choice(tile.map_source.subdomains))
        #print "Download {}".format(uri)
        data = requests.get(uri, timeout=5).content
        with open(cache_fn, "wb") as fd:
            fd.write(data)
        #print "Downloaded {} bytes: {}".format(len(data), uri)
        return tile.set_source, (cache_fn, )

    def _check_executor(self, dt):
        start = time()
        try:
            for future in as_completed(self._futures[:], 0):
                self._futures.remove(future)
                try:
                    result = future.result()
                except:
                    traceback.print_exc()
                    # make an error tile?
                    continue
                if result is None:
                    continue
                callback, args = result
                callback(*args)

                # capped executor in time, in order to prevent too much slowiness.
                # seems to works quite great with big zoom-in/out
                if time() - start > self.cap_time:
                    break
        except TimeoutError:
            pass