# coding=utf-8

'''
Created on May 12, 2016

@author: jrm
'''
from kivy.garden.mapview import MarkerMapLayer
from kivy.graphics import Line,Color,Mesh
from kivy.graphics.tesselator import Tesselator
from kivy.properties import NumericProperty,BooleanProperty, ObjectProperty, ListProperty
from kivy.uix.widget import Widget


class CollisionDetector(object):
    """ Interface used to detect if a widget should be displayed
        on the map.
    """
    def collides_with(self,bbox):
        """ Check if this object is within the bbox """
        raise NotImplementedError
    
    def on_collision(self):
        pass

class CanvasMapLayer(MarkerMapLayer):
    """ Map layer that uses the collision detector interface to check the 
        widget visibility so map widgets don't disappear if part of the widget is
        still visible. 
    """
    
    def reposition(self):
        if not self.markers:
            return
        mapview = self.parent
        bbox = None
        # reposition the markers depending the latitude
        markers = sorted(self.markers, key=lambda x: -x.lat)
        margin = max((max(marker.size) for marker in markers))
        bbox = mapview.get_bbox(margin)
        for marker in markers:
            can_detect_collision = isinstance(marker, CollisionDetector)
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

class MapLine(MapLayerWidget,CollisionDetector):
    # Width of the line in meters
    width = NumericProperty(30)
    
    # List of coordinates that make up this line
    coordinates = ListProperty([])
    
    # If the the line should close itself (ie add a last point == first point)
    closed = BooleanProperty(False)
    
    # If the area should be filled
    fill = BooleanProperty(False)
    
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
    
    def get_px_from_zoom(self,d):
        """ Get width in px of distance in meters"""
        return d*(2**(self.map.zoom+self.map._scale-1))/156412.0
        
    def update_line(self):
        """ Redraw the line on the canvas """
        if not self.coordinates:
            return
        xydata = [p for p in self._generate_points()]
        n = len(self.coordinates)
        with self.canvas:
            self.canvas.clear()
            Color(*self.color)
            Line(points=xydata,
                 width=self.get_px_from_zoom(self.width),
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
        for i,c in enumerate(self.coordinates):
            x,y = self.map.get_window_xy_from(c.lat,c.lon,zoom)
            if i==0 and self.closed:
                x0,y0=x,y
            yield x
            yield y
        if self.closed:
            yield x0
            yield y0
    
    def on_collision(self,*args):
        """ When the layer is repositioned, redraw """
        self.update_line()
    
    def on_pos(self,*args):
        """ When the map position moves, redraw """
        self.update_line()
    
    def on_coordinates(self,*args):
        """ When the coordinates are changed, redraw """
        self.update_line()
    