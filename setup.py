from setuptools import setup, Extension
#from Cython.Build import cythonize
extensions = [
    Extension("mapview.source", ["mapview/source.pyx"]),
    Extension("mapview.types", ["mapview/types.pyx"]),
    Extension("mapview.utils", ["mapview/utils.pyx"]),
    Extension("mapview.view", ["mapview/view.pyx"]),
    Extension("mapview.widgets", ["mapview/widgets.pyx"]),
]
setup(
    name = 'Cythonized MapView',
    packages = ['mapview'],
    ext_modules = extensions#cythonize("mapview/*.pyx")
)