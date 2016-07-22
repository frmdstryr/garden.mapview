# coding=utf-8
__all__ = ["Downloader"]

import os
from os.path import exists
from os import makedirs
from random import choice
from mapview import CACHE_DIR
from urlparse import urlparse

from twisted.python import log
from twisted.internet import reactor,defer, ssl
from twisted.internet.defer import Deferred, inlineCallbacks
from twisted.internet.endpoints import TCP4ClientEndpoint
from twisted.internet.protocol import Protocol
from OpenSSL import SSL
from twisted.web.client import Agent, ProxyAgent, HTTPConnectionPool, BrowserLikePolicyForHTTPS


class MyPolicy(BrowserLikePolicyForHTTPS):
    def creatorForNetloc(self, hostname, port):
        return ssl.optionsForClientTLS(
            hostname.decode("ascii"),
            extraCertificateOptions={'method': SSL.SSLv3_METHOD},
            trustRoot=self._trustRoot
        )

class Downloader(object):
    """ Downloader that uses twisted's web client
        instead of threads.  
        
        Note: Currently does NOT support using HTTPS through a proxy!
    
    """
    _instance = None
    MAX_WORKERS = 5
    CAP_TIME = 0.064  # 15 FPS

    @staticmethod
    def instance():
        if Downloader._instance is None:
            Downloader._instance = Downloader()
        return Downloader._instance

    def __init__(self, max_workers=None, cap_time=None):
        if max_workers is None:
            max_workers = Downloader.MAX_WORKERS
        if cap_time is None:
            cap_time = Downloader.CAP_TIME
        super(Downloader, self).__init__()
        self.is_paused = False
        self.cap_time = cap_time
        
        pool = HTTPConnectionPool(reactor, persistent=True)
        pool.maxPersistentPerHost = max_workers
        
        if 'HTTP_PROXY' in os.environ:
            proxy = urlparse(os.environ['HTTP_PROXY'])
            endpoint = TCP4ClientEndpoint(reactor, proxy.hostname, proxy.port or 8080)
            self.agent = ProxyAgent(endpoint,pool=pool)
        else:
            self.agent = Agent(reactor,pool=pool)
        
        if not exists(CACHE_DIR):
            makedirs(CACHE_DIR)

    def submit(self, f, *args, **kwargs):
        reactor.callInThread(f,*args,**kwargs)
    
    def download_tile(self, tile):
        defer.maybeDeferred(self._load_tile,tile)
    
    @inlineCallbacks
    def download(self, url, callback, **kwargs):
        d = self.agent.request("GET",url)
        d.addErrback(log.err)
        response = yield d
        if not response:
            return # Failed!
        d = self._load_page(response)
        d.addCallbacks(callback,log.err)

    @inlineCallbacks
    def _load_tile(self, tile):
        if tile.state == "done":
            return
        cache_fn = tile.cache_fn
        if exists(cache_fn):
            tile.set_source(cache_fn)
        tile_y = tile.map_source.get_row_count(tile.zoom) - tile.tile_y - 1
        uri = tile.map_source.url.format(z=tile.zoom, x=tile.tile_x, y=tile_y,
                              s=choice(tile.map_source.subdomains))
        
        # Do request
        request = self.agent.request("GET",uri)
        request.addErrback(log.err)
        
        # Set timeout
        reactor.callLater(5,request.cancel)
        
        # Upon response for response 
        response = yield request
        parse = self._load_page(response)
        parse.addErrback(log.err)
        data = yield parse
        
        with open(cache_fn, "wb") as fd:
            fd.write(data)
        #print "Downloaded {} bytes: {}".format(len(data), uri)
        tile.set_source(cache_fn)

    def _load_page(self,response):
        """ Return body of response """
        d = Deferred()
        chunks = []
        
        class BodyReceiver(Protocol):
            def dataReceived(self, data):
                chunks.append(data)
            def connectionLost(self, reason):
                d.callback(''.join(chunks))
        
        if response:
            response.deliverBody(BodyReceiver())
        else:
            d.errback()
            
        return d
