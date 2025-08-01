# Python

## Key Concepts

### Run Python interpreter in interactive mode
- Find where python3 lives with `which python3`
- `exit()` to quit.
- `python3 -c cmd args` also `python3 my_file.py` to run a command or file.
- Python is run in "interactive mode" when you type `python3` and then see `>>>` for the next prompt.
- You need to press `tab` after entering an if block for example.


### Encoding in a python file
- You can shebang a python script: `#!/usr/bin/env python3`
- You can select another encoding other than UTF-8 with a special comment from [this list](https://docs.python.org/3/library/codecs.html#standard-encodings). Python comes with a number of `codecs` built-in.
- Example: `# -*- coding: cp1252 -*-`. **This needs to be the first line of the file other than shebang!**
- Codecs have aliases which you can reference them by. For example, UTF-8 aliases are: `U8`, `UTF`, `utf8`, `cp65001`.


### Create Comments

```python
# this is a comment

"""
This is a 
multiline comment
between """ """.
"""
```

### Understand Data types
- Numerical:
    - `int`: Whole Numbers.
    - `float`: Decimal numbers.
    - `complex`: example `1+2j` which is rare.
    - Can perform arithmetic, comparison and built-in numerical functions like abs() and pow()

- Text Type:
    - `str`
    - Can perform concatenation (`'hello' + 'world'`), repetition (`'ha' * 3`), Can perform slicing `'hello[1:4]'`
    - Supports methods like `.upper()`, `.lower()`, `.replace()`, `.split()`, `.strip()`, `.join()`.
    - Supports membership like `'e' in 'hello'`

- Sequence Type:
    - `list`: Ordered, mutable. `[1,2,3]`
    - `tuple`: Ordered, *immutable* `(1,2,3)`
    - `range`: generator of numbers. `range(5)`
    - Supports indexing (`my_list[0]`), supports slicing (`my_list[1:3]`), supports `.len()` and membership `in` or `not in`

- Mapping Type:
    - `dict`: Key-Value pairs. `{'a': 1, 'b': 2}`
    - Supports access (`my_dictionary['a']`) and membership `in` or `not in`.
    - Supports updating (`my_dictionaryp['a'] = 40`)
    - Access keys and values: `.keys()`, `.values()`, `.items()`

- Set Types:
    - `set`: Unorderded, *unique* values
    - `frozenset`: Immutable set.
    - Supports `.add()`, `.remove()`, `.union()`, `.intersection()`, `.difference()`
    - Fast membership checking like `2 in my_set`

- Boolean Type:
    - `True/False`
    - Supports `and`, `or`, `not` operators
    - Bools are often returned by comparison operators.

- NoneType:
    - `None`

### Basic Data Type Operations

- Use `dir(x)` where `x` is the data type to see all the operators.
```python
dir(str)
dir(list)
dir(set)
```

- Can also use `help(x)` where `x` is the data type to get a scrollable man page.

```python
a = [1,2]
print(hasattr(a, '__add__')) # prints True
```

### Which Statements exist

- Conditional branching with `if`, `elif`, `else`
- Looping constructs with `for` and `while`
- Loop Control: `break`, `continue`
- Placeholder: `pass`
- Define a function: `def`
- Define a class: `class`
- Expression/functions: `lambda`
- Return from a function: `return`
- Importing modules: `import`, `from`
- Error handling: `try`, `except`, `finally`, `raise`
- Context with files for example: `with`
- Debug sanity check: `assert`
- Delete a variable/item: `del`
- Generator-producing: `yield`, `yield from`
- Async IO & Concurrency: `async`, `await`

- Examples:
```python
# Error handling with try, finally
except E as N: # catch exception of type E and assign to var N
    try:
        print("inside try")
    finally: # no matter what happens, delete N var from memory
        del N

# Loops and loop control
for i in range(5):
    if i == 2:
        continue # skips 2
    elif i == 3:
        print("we counted to 3")
    if i == 4:
        break # stops at 4
    print(i)

# Using while
n = 0 # intialize counter
while n < 3:
    print(n)
    n += 1 # add to counter

# using pass
for i in range(3):
    pass # placeholder

# define a class
class Greeter
    def __init__(self, name):
        self.name = name
    def say_hi(self):
        return f"Hi, {self.name}"
```


### Function Arguments
- Arguments are passed after a function name, inside `()`.
- By default, the function must be called with the correct number of args.
- If you don't know how many args will be passed, you can use `*args`

```python
def my_func(*kids):
    print("the youngest child is " + kids[2])

print(my_func("Joe", "Jane", "Robert"))
```

### Unpack arguments
- Types of arguments from example: 
```python
def my_func(arg1, arg2="default", *args, **kwargs)

```
- `arg1` is a positional argument, it must be provided.
- `arg2="default"` is a default argument, means this is an optional.
- `*args` collects extra positional arguments as a *tuple*.
- `**kwargs` collects extra keyword argyments as a *dictionary*.

- Unpack a tuple using `*` when calling a function.
- Unpack a dictionary using `**` when calling a function.

### Use lamda function
- A **lambda** is like a mini function without a name, also known as an **anonymous funciton**.
- Lambdas are ideal for one-time or temporary use.
- `lambda arguments: expression`
```python
#lambda
add = lambda x, y: x +y
print(add(2,3)) # produces 5

# written as a function
def add(x, y):
    return x + y

# lambda with built in functions
nums = [1, 2, 3]
squares = list(map(lambda x: x**2, nums))
print(squares) # produces [1, 4, 9]


```




### Document a function
- `Docstrings`: shoprt for documentation strings, convey the purpose of python functions/modules/classes.

- Right after a function declaration, put `"""documentation_here"""` or `'''documentation_here'''`
- Access the docstring by using the `__doc__` method of the object.
- If you defined a docstring in a function, you can access it like below.

```python
print(my_function.__doc__)
```

- Only actual docstrings, that are the first statement inside a function/class/module are used by tools like `help()` i.e. `help(my_function)` will put you in an interactive terminal to scroll the docs.



### Function Annotations
- Function annotations attach metadata to the paramters and return value of a function.
    - They do not enforce type checking but are useful for *type hints*.

```python
def greet(name: str, age: int) -> str:
    return f"Hello, {name}. You are {age}."

# access with
print(greet.__annotations__)

# Output: {'name': <class 'str'>, 'age': <class 'int'>, 'return': <class 'str'>}

```

### Coding Style best practices

- 4 spaces per indentation level. *Never mix tabs and spaces*.
- Use blank lines to separate functions, classes and logical sections.
- `imports` should go at the top of the file, avoid importing all `from module import *`

```python
import os # standard library
import sys # standard library

import requests # third party

from my_module import my_function # local import
```

- Naming Conventions:

|Type|Convention|Example| 
|-----|------| ------|
|Variables| snake_case| my_variable|
|Functions|snake_case|get_user_data()|
|Constants|UPPER_CASE|MAX_RETRIES|
|Classes|PascalCase|UserProfile|
|Internals |prefix with `_`|_internal_method()|

- Use `is` and `is not` when comparing to `None`.
`if value is None:`

- Use **List Comprehension** `squares = [x * x for x in range(10)]`

- Use requirements.txt to install packages using pip. i.e. `pip3 install -r requirements.txt`

- Use linting tools installed by pip like `pip3 install flake8 black isort`
    - `black .` to reformat your .py files recursively to PEP 8 quality.
    - `isort .` organizes your imports into groups
    - `flake8 .` to lint for style and bug issues, as well as unused imports.



### List Comprehension

- **List comprehension** creates a new list by transforming or filtering items from an existing iterable (list, tuple, range, etc).
- Basic syntax: `[expression for item in iterable]`
    - **expression** is what you want in the list.
    - **item** is the variable representing the value in the iterable. (item in a list).
    - **iterable** is the sequence itself (tuple, string, range, etc).

instead of this:
```python
result = []
for x in range(5):
    result.append(x * 2)
```

write this:

```python
result = [x * 2 for x in range(5)]
```
- You can also use with a condition (filtering).
```python
[expression for item in iterable if condition]

even = [x for x in range(20) if x % == 0]
```

- Supports `if + else` logic
```python
[expression_if_true if condition else expression_if_false for item in iterable]

labels = ["even" if x % 2 == 0 else "odd" for x in range(5)]
```

- Can be used to create pairs with all combinations (cartesean)

```python
pairs = [(x,y) for x in [1, 2] for y in ['a', 'b']]
# Output: [(1, 'a'), (1, 'b'), (2, 'a'), (2, 'b')]
```


### Mutable vs Immutable data types
- **Mutable** types are things like *lists* or *dictionaries*, as well as *sets* and *byte arrays*. These can be changed without creating a new object.
    - **More memory efficient** as they allow changes without allocating new memory.
    - Mutable data types are not thread safe.
    - Not hashable.
- **Immutable** types are things like *strings*, *integers*, and *tuples*, *frozenset*, *bytes*, which cannot be altered after they are created, ensuring data integrity. Creating a new object is necessary when attempting to modify.
    - **Less memory efficient** as new objects are created.
    - Immutable types are hashable, making them suitable for dictionary keys or set elements.

### Comparison Operators

- Numerical operators: `==`, `!=`, `>`, `<`, `>=`, `<=`

- Identity (Object) operators: 
    - `is` the same object, results in `True` or `False`
    - `is not` not the same object, results in `True` or `False`

- Container operators:
    - `in` value is in container, results in `True` or `False`
    - `not in` value is not inc container, results in `True` or `False`

### Output Formatting
- `f""` syntax is called an **f-string** and is a formatted string literal.
```python
print(f"function is {myfunc}")

# Rounding with f strings
pi = 3.1459
print(f"Pi rounded to 2: {pi:2f}")

# Print with alignment
print(f"|{'Name':<10}|{'Age':>3}|"}) # left-align Name, right-align Age

```

- `str.format()` Method as well for templating strings.
```python
template = "{} is {} years old."
print(template.format("Bob", 25)) # Produces Bob is 25 years old.
```

- Other formatting
```python
value = 42
print(f"{value:08}") # 00000042 (pad with 0s)
print(f"{value:^10}") # '   42    ' (Centered)

ratio = 0.834
print(f"{ratio:.0%}") # 83% (percentage rounded to 2)
```

- Old syntax is `%`.
```python
name = "Charlie"
age = 24
print("%s is %d years old." % (name, age))
# Charlie is 24 years old.
```

### Reading and Writing files

- Python uses the `open()` function for files with the modes `r` (read), `w` (overwrite), `a` (append), `x` (Create, fails if exists), `t` (text mode), `b` (binary mode).
- `with open()` always closes the file after the block.

```python
file = open("file.txt", "r") # open for reading

# read the whole file
with open("file.txt", "r") as file:
    content = file.read()
    print(content)

# read line by line
with open("file.txt", "r") as file:
    for line in file:
        print(line(strip())) # .strip() removes \n

# read lines into a list
with open("file.txt", "r") as file:
    lines = file.readlines()
    print(lines) # list of lines


# open in write mode
with open("output.txt", "a") as file:
    file.write("Appending a new line.\n")
```

### Errors and Exceptions

- **Errors** are problems in code that stop it from running.
- **Exceptions** are special kinds of errors that you can handle with `try`/`except`.


|Type|Description|Example|
|----|-----|-----|
|`SyntaxError`|Code written incorrectly.|`if x = 3`|
|`NameError`|Variable not defined|`print(foo)`|
|`TypeError`| Wrong type used|`len(5)`|
|`ValueError`|Correct type but wrong value|`int("abc")`|
|`IndexError`|List index out of range|`list[99]`|
|`FileNotFoundError`| File doesnt exist| `open("not_here.txt")`|
|`KeyError`| Missing dict in key|`dict["missing"]`|

### Namespaces
- A **namespace** is a container (or a mapping/dictionary) where names are mapped to objects. It is basically a variable lookup table.

```python
x = 10
# x is a name.
# 10 is the object it refers to.
# this mapping of x = 10 lives in a namespace.
```

- Namespaces in Python exist in different levels:

|Namespace|Description|
|----|-----|
|Built-in|Contains built-in names like len(), int, print|
|Global|For names at the top level of module or script|
|Local| For names in a function or method|
|Enclosing| For names in outer functions|

```python
x = 5  # Global namespace

def outer():
    y = 10  # Enclosing namespace

    def inner():
        z = 15  # Local namespace
        print(x, y, z)

    inner()

outer()
# Would check built-ins finally
```
- Follows the LEGB rule (Local -> Enclosing -> Global -> Built-in)
- You can view a namespace using built-in functions
```python
globals() # Global namespace
locals() # Local namespace
dir() # Lists names in current scope
```

- Variable **shadowing** is when a local variable shares the same name as a global one.
    - These are isolated instances of the variable and an *inner* `x = 5` var wouldn't change a globally defined `x = 10`.

### Object Oriented Programming
- A **class** is like a blueprint for creating an object.

```python
class Dog: # Define a class
    species = "Canine"  # Class attribute (shared)

    def __init__(self, name, age):  # Constructor
        self.name = name            # Instance attribute
        self.age = age              # Instance attribute

    def speak(self, sound):         # Instance method
        return f"{self.name} says {sound}"

# Create an object (instance)
my_dog = Dog("Rex", 5)

# Access data and call methods
print(my_dog.name)          # Rex
print(my_dog.speak("Woof")) # Rex says Woof
```


### Inheritence in Python

- You can create a new class that reuses behavior from another.

```python
# Define a base Server class
class Server:
    def __init__(self, name, ip_address):  
    # name, ip_address are parameters you pass when creating a server
    # Constructor, called when you create an object from the class
        self.name = name 
        self.ip_address = ip_address

    def start(self): # start is a method
        return f"{self.name} at {self.ip_address} is starting..."

    def stop(self): # stop is a method
        return f"{self.name} at {self.ip_address} is shutting down..."

# Now we'll inherit from the base class and create a new class
class WebServer(Server): # Automatically gets all methods from Server class
    def deploy_code(self): # deploy_code is a method specific to WebServer objects
        return f"Deploying web app to {self.name} at {self.ip_address}"

class DatabaseServer(Server):
    def backup(self):
        return f"Backing up database on {self.name} at {self.ip_address}"

```

### Private Variables

- You can use underscore conventions to indicate private data

```python
class BankAccount:
    def __init__(self, owner, balance):
        self.owner = owner
        self.__balance = balance  # "Private"

    def deposit(self, amount):
        self.__balance += amount

    def get_balance(self):
        return self.__balance

```

### Iterators vs Generators

- **iterable**: Anything you can loop over with a `for` loop. An object capable of returning its members one at a time. Two types:
    - *Sequence*: An iterable which supports efficient element access using integer indices. i.e. `my_list = [10, 20, 30]` can be accessed like `my_list[1] >> 20`. Can use `.len()` and `.reversed()`.
    - *Generator*: An object that returns a generator iterator. `yeild` turns the function into a generator.

```python
def count_up_to(n):
    count = 1
    while count <= n:
        yield count
        count += 1

gen = count_up_to(3)
print(next(gen)) # 1
print(next(gen)) # 2
print(next(gen)) # 3
```

### Other Basics

- **Virtual environment**: sandbox for python project, creates an isolated environment where you install packages and run code **without affecting the global Python installation** on your machine.
    - Create a venv with `python3 -m venv venv`. This creates a `venv/` folder containing a clean python env.
    - Activate the environment with `source venv/bin/activate` (on mac and linux)
    - Once active, your terminal will show `(venv) user@machine:~/project$`
    - Once done, you can type `deactivate`.
    - Add venv/ to your .gitignore
    - Tools like `poetry` or `pipenv` helps manage virtual environments.


- `f""` syntax is called an **f-string** and is a formatted string literal.
    - `print(f"function is {myfunc}")`

- A `Class` is a blueprint for creating objects. An `object` is an instance of a class, containing *data (attributes)* and *behavior (methods)*.

#### Built In Functions

##### Numbers and Math
- `min(x)` and `max(x)`: Print the smallest and largest val.
- `abs(x)`: absolute value
- `round(x)`: Round to the nearest int.
- `pow(x, y)`: Raise x to the power of y.
- `sum(iter)` sum all values in an iterable.

##### Strings and Types
- `str(x)`: Convert to string.
- `float(x)`: Convert to float.
- `len(x)`: Return the length of a list, string, etc.
- `type(x)`: Return the class/type of x.

 ##### Function
- `list(iter)`: Converts to list.
- `tuple(iter)`: Converts to tuple `tuple([1,2])` becomes `(1,2)`
- `dict()`: Creates a dictionary: `dict(a=1, b=2)` results in `{'a':1, 'b':2}`
- `sorted(iter)`: Return a sorted list.
- `reversed(iter)`: Returns a reversed iterator.

##### Logic and Checking
- `all(iter)`: Returns True if all are true.
- `any(iter)`: Returns True if any are true.
- `bool(x)`: Convert to boolean, `bool(0) == False`

##### Input and Output
- `print(x)`
- `input()`: gets user input.

##### Miscellaneous
- `range(start, stop)`: Creates a sequence of numbers. `list(range(1,4))`
- `enumerate(iter)`: index + value pairing. `list(enumerate['a','b'])`
- `zip(a, b)`: pairs elements from two iterables. A zipper. `list(zip[1, 2], ['a','b'])` output would be `[(1, 'a'), (2, 'b')]`
- `map(func, iter)`: Apply a function. `list(map(str.upper, ['a','b']))`
- `filter(func, iter)`: Filter items based on condition `list(filter(str.islower, 'AbC'))`

### Testing

- Integration testing: testing multiple components.
- Unit testing: Checks a single component

```python
# Below code will return nothing as it is true
assert sum([1,2,3]) == 6, "Should be 6"

# Defining a test case (test_sum.py)
def test_sum():
    assert sum([1,2,3]) == 6, "Should be 6"

if __name__ == '__main__':
    test_sum()
    print("Everything passed.")
```
- If false, returns `AssertionError`

- **Test Runners**:
    - `unittest`: requires that tests are put into classes as methods. `import unittest`
    - `nose` or `nose2`: will try to discover all test scripts named `test*.py` and any `unittest.TestCase` in current directory.
    - `pytest`: pytest test cases are functions in python starting with `test_`, supports `assert`

```python
import unittest

class TestSum(unittest.TestCase):

    def test_sum(self):
        self.assertEqual(sum([1,2,3]), 6, "Should be 6")

if __name__ == '__main__':
    unittest.main()

```
- Can call with: `python3 -m unittest test` or `python3 -m unittest discover`

- Other assertions: `.assertTrue(x)`, `.assertIs(a, b)`, `.assertIsInstance(a, b)`

- `Mocks`: Mock data for function calls, use it to patch the call and provide a static value:

```python
@pytest.fixture(params=['nodict', 'dict'])
def generate_initial_transform_parameters(request, mocker):
    [...]
    mocker.patch.object(outside_module, 'do_something')
    mocker.do_something.return_value(1)
    [...]
```

### Python Standard Library

```python
import os
os.getcwd()

import shutil
# directory and file tasks
shutil.copyfile('file1', 'file2')

import glob
# file wild cards
glob.glob('*.py)

import sys
print(sys.argv)

import re
# regular expression tools
re.sub(r'(\b[a-z]+) \1', r'\1', 'cat in the the hat')
# pattern: r'(\b[a-z]+) \1'
# \b: boundary, match only sub string
# [a-z]+: one or more lowercase
# r'\1': looks for the same word again
```

```python
import math
math.log(1024, 2) # -> 10.0

import random
random.choice([1,2,3,4])

import statistics
data = [1.5, 2.0, 3]
statistics.mean(data)


from urllib.request import urlopen
with urlopen('http://docs.python.org3/tutorial/stdlib.html') as response:
    for line in response:
        line = line.decode() # Convert bytes to a str

from datetime import date
birthday = date(1964, 7, 10)
age = now - birthday
age.days

import pprint
# prettier print
pprint.pprint(variable, width=30)

import textwrap
print(textwrap.fill(textVar, width=40))

from string import Template
t = Template('${village} folk send $$10 to ${cause}.')
# need to escape extra $
t.substitute(village='Florida', cause='the ditch fund')


import logging
logging.debug('Debugging Info)
logging.warning('Warning:config file %s not found', 'server.conf')

# weakref tracks object without creating a reference
import weakref, gc
d = weakref.WeakValueDictionary()
# weakref prevents it from being gc garbage collected
gc.collect()
```

### Package maangement and Venv
- Running pip as a module `python3 -m pip`
- Running pip in a venev allows you to use the right python version, and make sure you are referencing the right package versions.

```python
# Check your current packages
python3 -m pip list`

python3 -m pip show requests # alternatively
import requests
requests.__version__

# Installing packages in editable mode
git clone https://github.com/realpython/rptree
cd rptree
python -m venv venv/
source venv/bin/activate
python -m pip install -e .

# Freeze the requirements file
python3 -m pip freeze > requirements.txt
```

- Example requirements.txt, can also use requirements_dev.txt:
```python
# example requirements file
certifi>=x.y.z
charset-normalizer>=x.y.z
idna>=x.y.z
requests>=x.y.z, <3.0
urllib3>=x.y.z
```

- Set up a virtual environment:
    - `python3 -m venv venv/`
    - `source venv/bin/activate`
    - Your python environment contains: (1) interpreter, (2) standard library, (3) installed packages.
    - To manage multiple versions of Python, use pyenv (python version manager): `pyenv install 3.12.2`

- Other package managers include: `Conda`, `Poetry`, `Pipenv`, `uv`

- **PyPI** (`https://pypi.org`) stands for Python Package Index, the official repo for python packages.
- PyPI Workflow:
1) `pip install flask`
2) PyPI hosts: source code (.tar.gz ), built distibutions (.whl, "wheels"), metadata (version, dependencies)
- **Note**: pip is a package manager, while PyPI is a repo for packages.
- Upload a package to pyPI by having: `Python3` installed, `pip`, `build` and `twine`, and `a PyPI account`, as well as a certain repository structure.

### Python Profilers

- **Python Profilers** are tools that help you understand where code is spending time, how much memory is used, so you can optimize performance.
- Source code: `Lib/profile.py` and `Lib/pstats.py` (statistics can be formatted with pstats)
- `cProfile` is recommended for most users, a built-in C extension. Standard, and reliable
- `profile` is a pure Python module.
- `line_profiler` which needs `@profile `decorator
- `memory_profiler` line by line memory usage, with `@profile` decorator
- `SnakeViz` is a vizualization tool for cProfile.
- Profile results: 
    - `ncalls`: number of calls
    - `tottime`: time spent in a given function
    - `percall` quotient diveded by ncalls
    - `filename:lineo(function)`: provides respective data of each func.

```python
import cProfile
import re
cProfile.run('re.compile("foo|bar")')

# line_profiler
pip install line_profiler
@profile
def process_data():
    ...

# In practice:
python3 -m cProfile myscript.py
```

### Serialization/Deserialization

- `Serialization` (pickling), is the process of translating a data structure into a storable format.
    - Used for data transfer across networks, storing data, detecting changes in time-varying data.
- `Deserialization` (unmarshalling), is extracting the data structure from  a series of bytes.

### Python and Json/XML/YAML

- **JSON** stands for JavaScript Object Notation

```python
import json # JSON encoder/decoder
json.dumps(['foo, :'bar': ('baz', None, 1.0, 2)}])
# -> '["foo", {"bar": ["baz", null, 1.0, 2]}]'


json.loads('["foo", {"bar":["baz", null, 1.0, 2]}]')
# -> ['foo', {'bar': ['baz', None, 1.0, 2]}]

echo '{"json":"obj"}' | python -m json.tool
# {
#     "json": "obj"
# }
```

- **XML** processing with `lxml.etree`

```python
import xml.etree.ElementTree as ET

xml_data = '''
<book>
  <title>Python Deep Dive</title>
  <author>Jane Doe</author>
</book>
'''

root = ET.fromstring(xml_data)
print(root.tag) 
print(root.text) 
```

- XML elements closely resemble Python lists.
- The E-Factory provides a way to generate XML and HTML

```python
from lxml.builder import E, ElementMaker
E.html(E.head(E.title("Sample document"))),
E.body(...)

Element = ElementMaker(namespace="https://my.de/fault/namespace",
                        nsmap={'p': "https://my.de/fault/namespace"})

```

- An XPath() method supports expressions in the xpath syntax

```python
from lxml import etree

f = StringIO('<foo><bar></bar></foo>')
tree = etree.parse(f)
r = tree.xpath('/foo/bar')
len(r) # 1
```

- Tree iteration, iterating over children of an XML
- ElementPath  in find*() is supported by ElementTree

```python
root = ET.fromstring(xml_data)
for book in root:
    title = book.find('title').text
    print(f"{title} is the title.")

# recursive tree walk with .iter()
for element in root.iter():
    print(element.tag, element.text)

# Access attributes
book.attrib['id']
```

- YAML is handled with **PyYAML** parser and emitter for python.
- YAML maps directly to python structures: str, int, list, dict, bool, None

```python
pip install pyyaml
from yaml import load, dump

with open("config.yaml", "r") as f:
    config = yaml.safe_load(f)
    # safe_load only works with basic types


data = my_example_json

# Dump from python into YAML file
with open("config.yaml", "w") as f1:
    yaml.dump(data, f, sort_keys=False)
```

### Debugging

- A debugger, like pdb or an IDE, helps with dynamic inspection of your code, without additional clutter.
- **PyCharm** is the Python IDE with powerful debuggin, classic JetBrains IDE style.

- `pdb` is the built-in command-line debugger.

```python
def divide(a, b):
    result = a / b
    return result

x = 10
y = 0

import pdb; pdb.set_trace()  # Set a breakpoint

print(divide(x, y))
```
- PDB commands: `n` (next), `s` (step), `c` (continue), `l` (list), `p var` (print variable value), `q` (quit debugger), `bt` (Show stack trace)