from setuptools import setup, Extension
#from Cython.Build import cythonize
extensions = [Extension("*", ["mapview/*.pyx"])]
setup(
    name = 'Cythonized MapView',
    packages = ['mapview'],
    ext_modules = extensions#cythonize("mapview/*.pyx")
)
