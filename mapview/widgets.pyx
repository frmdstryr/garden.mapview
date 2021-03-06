# coding=utf-8
'''
Created on May 12, 2016

@author: jrm
'''
from mapview import MarkerMapLayer
from kivy.graphics import SmoothLine,Line,Color,Mesh
from kivy.graphics.tesselator import Tesselator
from kivy.graphics.context_instructions import Scale, Translate
from kivy.properties import NumericProperty,BooleanProperty, ObjectProperty, ListProperty, OptionProperty
from kivy.uix.widget import Widget

class CollisionDetectorBehavior(object):
    def collides_with(self,bbox):
        """ Check if this object is within the bbox """
        raise NotImplementedError
    
    def on_collision(self):
        pass

class CanvasMapLayer(MarkerMapLayer):
    """ Supports widget visibility so marker widgets don't disappear if they
    should still be visible. """
    
    _size = ObjectProperty(None)
    _zoom =  NumericProperty(0)
    
    mode = OptionProperty('scatter',options=['scatter','window'])
    
    def reposition(self):
        if not self.markers:
            return
        mapview = self.parent
        print "repos {} {}".format(mapview.pos,mapview.size)
        if (mapview.zoom == self._zoom):# and (mapview.size == self._size):
            # Only redraw when zoom changes or map is repositioned
            return
        print "zoom changed bro {}".format(self)
        self._size = mapview.size
        self._zoom = mapview.zoom
        
        # reposition the markers depending the latitude
        markers = sorted(self.markers, key=lambda x: -x.lat)
        margin = max((max(marker.size) for marker in markers))
        bbox = mapview.get_bbox(margin)
        for marker in markers:
            can_detect_collision = isinstance(marker, CollisionDetectorBehavior)
            if bbox.collide(marker.lat, marker.lon) or \
                (can_detect_collision and marker.collides_with(bbox)):
                self.set_marker_position(mapview, marker)
                if not marker.parent:
                    super(MarkerMapLayer, self).add_widget(marker)
                if can_detect_collision:
                    marker.on_collision()
            else:
                super(MarkerMapLayer, self).remove_widget(marker) 


class MapLayerWidget(Widget):
    """ Generic Widget on map """
    anchor_x = NumericProperty(0.5)
    """Anchor of the marker on the X axis. Defaults to 0.5, mean the anchor will
    be at the X center of the image.
    """

    anchor_y = NumericProperty(0)
    """Anchor of the marker on the Y axis. Defaults to 0, mean the anchor will
    be at the Y bottom of the image.
    """

    lat = NumericProperty(0)
    """Latitude of the marker
    """

    lon = NumericProperty(0)
    """Longitude of the marker
    """
    
    
    # (internal) reference to its layer
    _layer = ObjectProperty(None,allownone=True)
    
    def detach(self):
        if self._layer:
            self._layer.remove_widget(self)
            self._layer = None

class MapLine(MapLayerWidget,CollisionDetectorBehavior):
    # Width of the line in meters
    width = NumericProperty(30)
    
    # List of coordinates that make up this line
    coordinates = ListProperty([])
    
    # If the the line should close itself (ie add a last point == first point)
    closed = BooleanProperty(False)
    
    # If the area should be filled
    fill = BooleanProperty(False)
    
    # If the area should be filled
    type = OptionProperty('line',options=['line','smoothline'])
    
    # Fill color
    fill_color = ListProperty([0,1,0,0.2])
    
    # Color of the line
    color = ListProperty([0,1,0,1]) 
    
    @property
    def map(self):
        return self._layer.parent
    
    def collides_with(self, bbox):
        """ Check if the line should still be shown on the map. """
        for c in self.coordinates:
            if bbox.collide(c.lat,c.lon):
                return True
        return False
    
    def get_px_from_zoom(self,float d):
        """ Get width in px of distance in meters"""
        return d*(2**(self.map.zoom+self.map._scale-1))/156412.0
        
    def update_line(self,reposition=False):
        """ Redraw the line on the canvas """
        if not self.coordinates:
            return
        print "update line {}".format(self)
        scatter = self.map._scatter
        x,y,s = scatter.x, scatter.y, scatter.scale
        xydata = self._generate_points()
        n = len(self.coordinates)
        print n, x, y, s, reposition
        with self.canvas:
            self.canvas.clear()
            
            if reposition:
                Scale(1/s,1/s,1)
                Translate(-x,-y)
            
            Color(*self.color)
            if self.type=='line':
                Line(points=xydata,
                     width=self.get_px_from_zoom(self.width),
                     close=self.closed,
                     cap='square',joint='round')
            else:
                SmoothLine(points=xydata,
                     width=self.get_px_from_zoom(self.width),
                     close=self.closed,
                     cap='square',joint='round')
                
            if self.fill and n>2:
                t = Tesselator()
                t.add_contour(xydata)
                if t.tesselate():
                    Color(*self.fill_color)
                    for v,i in t.meshes:
                        Mesh(vertices=v,indices=i,mode='triangle_fan')
    
    def _generate_points(self):
        """ Generate all the points based on lat & long of the coordinates """
        zoom = self.map.zoom
        points = []
        for c in self.coordinates:
            points += self.map.get_window_xy_from(c.lat,c.lon,zoom)
        return points
    
    def on_size(self,*args):
        super(MapLine, self).on_size(*args)
        print "on size {}".format(self.size)
    
    def on_pos(self,*args):
        print "on posi {}".format(self.pos)
    
    def on_collision(self,*args):
        """ When the layer is repositioned, redraw """
        print "on collish"
        self.update_line(reposition=True)
    
    def on_coordinates(self,*args):
        """ When the coordinates are changed, redraw """
        print "on coords"
        self.update_line()
    