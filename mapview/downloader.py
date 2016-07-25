# coding=utf-8
__all__ = ["Downloader"]

from os.path import exists
from os import makedirs
from mapview import CACHE_DIR

class Downloader(object):
    _instance = None
    MAX_WORKERS = 5
    CAP_TIME = 0.064  # 15 FPS
    
    # Set this to the implementing class
    factory = None

    @staticmethod
    def instance():
        if Downloader._instance is None:
            if Downloader.factory is None:
                raise RuntimeError("No downloader factory configured!")
            Downloader._instance = Downloader.factory()
        return Downloader._instance
    
    def __init__(self, max_workers=None, cap_time=None):
        if max_workers is None:
            max_workers = Downloader.MAX_WORKERS
        if cap_time is None:
            cap_time = Downloader.CAP_TIME
        super(Downloader, self).__init__()
        self.is_paused = False
        self.max_workers = max_workers
        self.cap_time = cap_time
        
        # Init subclass
        self.setup()
        
        if not exists(CACHE_DIR):
            makedirs(CACHE_DIR)
            
    def setup(self):
        raise NotImplementedError

    def submit(self, f, *args, **kwargs):
        raise NotImplementedError
    
    def download_tile(self, tile):
        raise NotImplementedError
    
    def download(self, url, callback, **kwargs):
        raise NotImplementedError
    
try:
    from mapview.downloaders.threaded import ThreadedDownloader
    
    # Set factory
    Downloader.factory = ThreadedDownloader
except ImportError as e:
    print(e)

try:
    from mapview.downloaders.async import AsyncDownloader    
    # Set twisted as default    
    Downloader.factory = AsyncDownloader
except ImportError as e:
    print(e)
