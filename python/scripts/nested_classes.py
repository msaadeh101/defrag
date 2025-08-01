from datetime import datetime, timedelta

class Homework:
    def __init__(self, text: str, days_to_complete: int):
        self.text = text
        self.created = datetime.now()
        self.days_to_complete = days_to_complete
        self.deadline = timedelta(days=days_to_complete)

    def is_active(self) -> bool:
        return datetime.now() < self.due_date

    @property
    def due_date(self) -> datetime:
        return self.created + self.deadline

    def time_remaining(self) -> str:
        remaining = self.due_date - datetime.now()
        if remaining.days > 0:
            return f"{remaining.days} day(s)"
        elif remaining.days < 0:
            return "Overdue"


class Student:
    def __init__(self, first_name: str, last_name: str) -> None:
        self.first_name = first_name
        self.last_name = last_name

    def do_homework(self, homework: Homework):
        if homework.is_active():
            remaining_days = (homework.created + homework.deadline - datetime.now()).days
            print(f"your home work is due in {remaining_days} days, {self.first_name}.\n I mean, its only {homework.text}.")
            return homework
        print(f"you are late {self.first_name}")
        return None

class Teacher:
    def __init__(self, first_name: str, last_name: str) -> None:
        self.first_name = first_name
        self.last_name = last_name

    @staticmethod
    def create_homework(text: str, days_to_complete: int) -> Homework:
        return Homework(text, days_to_complete)

def main():
    teacher = Teacher('Mr', 'Smith')
    student = Student('Mike', 'Jones')

    homework = Homework("Complete assignment 1", -1)
    result = student.do_homework(homework)

    if result:
        print(f"Homework accepted by {student.first_name}")
        print(f"Homework assigned by {teacher.first_name} {teacher.last_name}")
    else:
        print(f"{student.first_name} failed to complete the homework in {abs(homework.days_to_complete)} day(s)")

if __name__ == '__main__':
    main()