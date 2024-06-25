#include "basic.h"

int add(int a, int b) {
    return a + b;
}

int check(int a, int b) {
    return a == b;
}

void set(int *a, int b) {
    *a = b;
}

int runOpFunc(opFunc op, int a, int b) {
   return ((opFunc)op)(a, b);
}

int validateStruct(struct simpleUnknownStruct* s, char a, float b, int c) {
    return s->a == a && s->b == b && s->c == c;
}