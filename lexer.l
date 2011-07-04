%option noyywrap
%option nomain
%option yylineno
%option case-insensitive

%{
#include <stdio.h>
#include "quadrupelcode.h"
#include "parser.tab.h"

// unary plus and minus can only appear at line beginnings and after opening paranthesises or *,/,%
int unary_flag=0;
%}

NEWLINE (\n|\n\l|\r\n)
WHITESPACE (" "|\t)
SINGLELINE_COMMENT ("//".*{NEWLINE})
MULTILINE_COMMENT ("/*".*"*/")
PREPROCESSOR ("#".*{NEWLINE})
INTEGER (0|[1-9][0-9]*)
FLOAT (0\.0|[1-9][0-9]*\.[0-9]+)
IDENTIFIER ([a-zA-Z_][a-zA-Z0-9_]*)

%%

({NEWLINE}+|{WHITESPACE}+) {
    // ignore whitespaces and newlines
    //printf("LEXER: found whitespace or newline sequence\n");
}

({SINGLELINE_COMMENT}|{MULTILINE_COMMENT}) {
    // ingore comments
    printf("LEXER: found comment\n");
}

{PREPROCESSOR} {
    // ignore preprocessor directives
    printf("LEXER: found preprocessor directive\n");
}

^("+"|"-") {
    // must be unary
    if('+' == yytext[0]) {
        printf("LEXER: found unary +\n");
        return(U_PLUS);
    } else {
        printf("LEXER: found unary -\n");
        return(U_MINUS);
    }
    unary_flag = 0;
}

("("|")"|"{"|"}"|"<"|">"|"="|";"|","|"!") {
    printf("LEXER: found %c\n", yytext[0]);
    unary_flag = 1;
    return(yytext[0]);
}

("/"|"*"|"%") {
    printf("LEXER: found %c, changed to unary mode}\n", yytext[0]);
    unary_flag = 1;
    return(yytext[0]);
}

("+"|"-") {
    if(1 == unary_flag) {
        if('+' == yytext[0]) {
            printf("LEXER: found unary +\n");
            return(U_PLUS);
        } else {
            printf("LEXER: found unary -\n");
            return(U_MINUS);
        }
        unary_flag = 0;
    } else {
        printf("LEXER: found %c\n", yytext[0]);
        return(yytext[0]);
    }
}

"void" {
    printf("LEXER: found VOID\n");
    return(VOID);
}

"int" {
    printf("LEXER: found INT\n");
    return(INT);
}

"float" {
    printf("LEXER: found FLOAT\n");
    return(FLOAT);
}

"constant" {
    printf("LEXER: found NUMERICAL CONSTANT\n");
    return(CONSTANT);
}

"if" {
    printf("LEXER: found IF\n");
    return(IF);
}

"else" {
    printf("LEXER: found ELSE\n");
    return(ELSE);
}

"return" {
    printf("LEXER: found RETURN\n");
    return(RETURN);
}

"do" {
    printf("LEXER: found DO\n");
    return(DO);
}

"while" {
    printf("LEXER: found WHILE\n");
    return(WHILE);
}

"for" {
    printf("LEXER: found FOR\n");
    return(FOR);
}

"++" {
    printf("LEXER: found ++\n");
    return(INC_OP);
}

"--" {
    printf("LEXER: found --\n");
    return(DEC_OP);
}

"==" {
    printf("LEXER: found ==\n");
    return(EQUAL);
}

"!=" {
    printf("LEXER: found !=\n");
    return(NOT_EQUAL);
}

">=" {
    printf("LEXER: found >=\n");
    return(GREATER_OR_EQUAL);
}

"<=" {
    printf("LEXER: found <=\n");
    return(LESS_OR_EQUAL);
}

"<<" {
    printf("LEXER: found <<\n");
    return(SHIFTLEFT);
}

"&&" {
    printf("LEXER: found &&=\n");
    return(LOG_AND);
}

"||" {
    printf("LEXER: found ||\n");
    return(LOG_OR);
}

{INTEGER} {
    printf("LEXER: found integer constant: %d\n", atoi(yytext));
    yylval.expr.value = strdup(yytext);
    yylval.expr.cType = C_CONSTANT;
    yylval.expr.type = ST_INT;
    unary_flag = 0;
    return(CONSTANT);
}

{FLOAT} {
    printf("LEXER: found float constant: %f\n", atof(yytext));
    yylval.expr.value = strdup(yytext);
    yylval.expr.cType = C_CONSTANT;
    yylval.expr.type = ST_REAL;
    unary_flag = 0;
    return(CONSTANT);
}

{IDENTIFIER} {
    printf("LEXER: found identifier: %s\n", yytext);
    yylval.str = malloc(strlen(yytext)*sizeof(char)+1);
    strcpy(yylval.str, yytext);
    unary_flag = 0;
    return(IDENTIFIER);
}

%%
