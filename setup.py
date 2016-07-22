from setuptools import setup, Extension

try:
    from Cython.Build import cythonize
    has_cython = True
except:
    has_cython = False

extensions = [
    Extension("mapview.source", ["mapview/source.pyx"]),
    Extension("mapview.types", ["mapview/types.pyx"]),
    Extension("mapview.utils", ["mapview/utils.pyx"]),
    Extension("mapview.view", ["mapview/view.pyx"]),
    Extension("mapview.widgets", ["mapview/widgets.pyx"]),
]

if has_cython:
    extensions = cythonize(extensions)

setup(
    name = 'Cythonized MapView',
    packages = ['mapview'],
    package_data={
       'mapview': ['icons/*.png'],
    },
    ext_modules = extensions
)