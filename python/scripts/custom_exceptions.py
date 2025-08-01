import typing

class DivisionByOneException(Exception):
    """Custom exception for division by 1"""
    pass

class DivisionByZeroException(Exception):
    """Custom exception for division by 0"""
    pass

def division(x: int, y: int) -> typing.Union[None, float]:
    finished_message = "Division finished"
    try:
        if y == 0:
            print("Division by Zero")
            raise DivisionByZeroException("You cannot divide by zero")
        elif y == 1:
            raise DivisionByOneException("Deletion by 1 returns the same result")
        else:
            return x / y
    finally:
        print(finished_message)

def main():
    try:
        print(division(1,0)) # Should return Division by 0
    except Exception as e:
        print(repr(e))
    try:
        print(division(1,1)) # Raise custom exception
    except Exception as e:
        print(repr(e))

if __name__ == '__main__':
    main()