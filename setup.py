from distutils.core import setup
from Cython.Build import cythonize

setup(
    name = 'Cythonized MapView',
    packages = ['mapview'],
    ext_modules = cythonize("mapview/*.pyx")
)
