typedef int (*opFunc)(int, int);

struct simpleUnknownStruct
{
    char a;
    float b;
    int c;
};

int add(int a, int b);

int check(int a, int b);

void set(int *a, int b);

int runOpFunc(opFunc op, int a, int b);

int validateStruct(struct simpleUnknownStruct* s, char a, float b, int c);