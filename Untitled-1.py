

def result(a, b, x):
    if x == '+':
        return (a+b)
    elif x == '-':
        return (a-b)
    elif x == '*':
        return (a*b)    
    elif x == '/':
        if b == 0:
            return "Error: Division by zero"
        return (a/b)    
    else:
        return "Invalid operation"

def main():
    a = int(input("Enter first number: "))
    b = int(input("Enter second number: ")) 
    x = input("Enter operation (+, -, *, /): ")
    print("Result:", result(a, b, x))

if __name__ == "__main__":
    main()