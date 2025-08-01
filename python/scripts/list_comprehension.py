from typing import List

squares = [x * x for x in range(1,11)]

print(f"list of squares from 1-10: {squares}")

reversed_list = list(reversed(squares))
print(f"reversed list is : {reversed_list}")

# Dictionary comprehension
squares_dict = {x: x**2 for x in range(5)}

print(f"dict is : {squares_dict}")

def if_else_assignment(list_of_nums: List):
    assignment = ['even' if x % 2 == 0 else 'odd' for x in list_of_nums]
    return assignment

print("value of if_else list comprehension funciton: ")
print(if_else_assignment(range(1, 11)))
even_odd_list = if_else_assignment(range(1,11))
even_odd_dict = dict(zip(range(1,11), even_odd_list))
print(even_odd_dict)