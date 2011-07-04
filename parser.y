%{
#include <stdio.h>
#include <string.h>
#include "quadrupelcode.h"

unsigned short parameter_count;
extern int yylineno;
extern char *yytext;
char quadBuffer[50];
int funcLineNumber = 0;

%}

%token VOID INT FLOAT CONSTANT IDENTIFIER
%token IF ELSE RETURN DO WHILE FOR
%token INC_OP DEC_OP U_PLUS U_MINUS  
%token EQUAL NOT_EQUAL GREATER_OR_EQUAL LESS_OR_EQUAL SHIFTLEFT LOG_AND LOG_OR

%right '='
%left LOG_OR    
%left LOG_AND
%left '<' '>' LESS_OR_EQUAL GREATER_OR_EQUAL
%left EQUAL NOT_EQUAL
%left SHIFTLEFT
%left '+' '-'
%left '*' '/' '%'
%right U_PLUS U_MINUS '!'
%left INC_OP DEC_OP

%union
{
    char         	*str;
    int           	integer;
    float         	real;
    int           	type;
	struct
	{
	    char                 	*value;
	    int   			type;
	    int				cType;
	    struct BackpatchList* 	trueList;
	    struct BackpatchList* 	falseList;
	} expr;
	struct
	{
	  struct BackpatchList* 	nextList;
	} stmt;
	struct
	{
	  int				quad;
	  struct BackpatchList* 	nextList;
	} mark;
	struct
	{
	    int				count;
	    struct SymbolTableEntry* 	queue;
	} exp_list;
}

%type <str> id IDENTIFIER
%type <type> declaration var_type
%type <expr> expression assignment CONSTANT
%type <stmt> statement statement_list matched_statement unmatched_statement program function_body function
%type <exp_list> exp_list
%type <mark> marker jump_marker
%start program_head

%%

program_head
    : program
	{
	    SymbolTableEntry* mainFunc = lookup("main");
	    if(mainFunc == NULL){
		printf("ERROR: Main function not found!\n");
		yyerror();
	    }
	    backpatch($1.nextList,mainFunc->line+1);
	}
    ;

program
    : jump_marker function
        {
            printf("PARSER: Processing single function.\n");
	    $$.nextList = $1.nextList;
            backpatch($2.nextList, nextquad());
            printf("PARSER: Done processing single function.\n");
        }
    | program function
        {
            printf("PARSER: Processing function in function list.\n");
	    $$.nextList = $1.nextList;
            backpatch($2.nextList, nextquad());
            printf("PARSER: Done processing function in function list.\n");
        }
    ;
						


function
    : var_type id '(' parameter_list ')' ';'
        {
            printf("PARSER: found function prototype for %s having %d parameters\n",$2,parameter_count);
            addFunctionPrototype($2, parameter_count, $1);
            parameter_count = 0;
            $$.nextList = NULL;
        }
    | var_type id '(' parameter_list ')' function_body
        {
            printf("PARSER: found function definition for %s having %d parameters starting at line %d\n", $2,parameter_count,funcLineNumber);
            addFunction($2, parameter_count, $1, funcLineNumber);
            parameter_count = 0;
	    funcLineNumber = nextquad();
            $$.nextList = $6.nextList;
        }
    ;

function_body
    : '{' statement_list  '}'
        {
            printf("PARSER: found function body without declarations\n");
            $$.nextList = $2.nextList;
        }
    | '{' declaration_list statement_list '}'
        {
            printf("PARSER: found function body with declarations\n");
            $$.nextList = $3.nextList;
        }
    ;

declaration_list
    : declaration ';'
        {
            printf("PARSER: found declaration\n");
        }
    | declaration_list declaration ';'
        {
            printf("PARSER: found declaration list\n");
        }
    ;

declaration
    : INT id
        {
            $$ = ST_INT;
            addSymbolToQueue($2, ST_INT, 0);
            printf("PARSER: found integer declaration\n");
        }
    | FLOAT id
        {
            $$ = ST_REAL;
            addSymbolToQueue($2, ST_REAL, 0);
            printf("PARSER: found float declaration\n");
        }
    | declaration ',' id
        {
            if(ST_INT == $1) {
                addSymbolToQueue($3, ST_INT, 0);
            } else if(ST_REAL == $1) {
                addSymbolToQueue($3, ST_REAL, 0);
            }
            printf("PARSER: found mutliple declarations\n");
        }
    ;

parameter_list
    : INT id
        {
            parameter_count++;
            addSymbolToQueue($2, ST_INT, parameter_count);
            printf("PARSER: found integer parameter\n");
        }
    | FLOAT id
        {
            parameter_count++;
            addSymbolToQueue($2, ST_REAL, parameter_count);
            printf("PARSER: found float parameter\n");
        }
    | parameter_list ',' INT id
        {
            parameter_count++;
            addSymbolToQueue($4, ST_INT, parameter_count);
            printf("PARSER: found parameter list with integer at end\n");
        }
    | parameter_list ',' FLOAT id
        {
            parameter_count++;
            addSymbolToQueue($4, ST_REAL, parameter_count);
            printf("PARSER: found parameter list with float at end\n");
        }
    | VOID
        {
            printf("PARSER: found void parameter\n");
        }
    |
        {
            printf("PARSER: found EPSILON parameter\n");
        }
    ;

var_type
    : INT
        {
            $$ = SIT_INT;
            printf("PARSER: found integer variable type\n");
        }
    | VOID
        {
            $$ = SIT_NONE;
            printf("PARSER: found void return type\n");
        }
    | FLOAT
        {
            $$ = SIT_REAL;
            printf("PARSER: found float variable type\n");
        }
    ;



statement_list
    : statement
        {
	    printf("PARSER: Processing single statement in list statement list.\n");
            $$.nextList = $1.nextList;
	    printf("PARSER: Done processing single statement in list statement list.\n");
        }
    | statement_list marker statement
        {
	    printf("PARSER: Processing statement list.\n");
	    backpatch($1.nextList,$2.quad);
	    $$.nextList = $3.nextList;
	    printf("PARSER: Done processing statement list.\n");
        }
    ;

statement
    : matched_statement
        {
	    printf("PARSER: Processing matched statement.\n");
	    $$.nextList = $1.nextList;
	    printf("PARSER: Done processing matched statement.\n");
        }
    | unmatched_statement
        {
	    printf("PARSER: Processing unmatched statement.\n");
	    $$.nextList = $1.nextList;
	    printf("PARSER: Done processing unmatched statement.\n");
        }
    ;

matched_statement
    : IF '(' assignment ')' marker matched_statement jump_marker ELSE marker matched_statement
        {
	    printf("PARSER: Processing matched if then else.\n");
	    backpatch($3.trueList,$5.quad);
	    backpatch($3.falseList,$9.quad);
	    $$.nextList = mergelists($7.nextList,$10.nextList);
	    $$.nextList = mergelists($$.nextList,$6.nextList);
	    printf("PARSER: Done processing matched if then else.\n");
        }
    | assignment ';'
        {
	    printf("PARSER: Processing matched assignment.\n");
        //backpatch($1.trueList, 1);
        //backpatch($1.falseList, 0);
	    $$.nextList = NULL;
	    printf("PARSER: Done processing matched assignment.\n");
	}
    | RETURN ';'
        {
	    //TODO: Check type, maybe true/falselists
	    printf("PARSER: Processing void return.\n");
	    $$.nextList = NULL;
	    sprintf(quadBuffer,"RETURN");
	    genquad(quadBuffer);
	    printf("PARSER: Done processing void return.\n");
        }
    | RETURN assignment ';'
        {
	    //TODO: Check type, maybe true/falselists
	    printf("PARSER: Processing return.\n");
	    $$.nextList = NULL;
            sprintf(quadBuffer,"RETURN %s",$2.value);
	    genquad(quadBuffer);
	    printf("PARSER: Done processing return.\n");
        }
    | WHILE marker '(' assignment ')' marker matched_statement jump_marker
        {
	    printf("PARSER: Processing matched while.\n");
	    backpatch($4.trueList,$6.quad);
	    $$.nextList = $4.falseList;
	    backpatch($7.nextList,$2.quad);
	    backpatch($8.nextList,$2.quad);
	    printf("PARSER: Done processing matched while.\n");
        }
    | DO marker statement WHILE '(' marker assignment ')' ';'
        {
	    backpatch($3.nextList,$6.quad);
	    backpatch($7.trueList,$2.quad);
	    $$.nextList = $7.falseList;
        }
    | FOR '(' assignment ';' marker assignment ';' marker assignment jump_marker ')' marker matched_statement jump_marker
        {
            printf("PARSER: Processing matched for\n");
            if(ST_BOOL == $3.type || ST_BOOL == $9.type) {
                printf("error, no boolean statements allowed as 1st or 3rd assignment in for loop\n");
                yyerror();
            }
            if(ST_BOOL != $6.type) {
                printf("error, 2nd argument of for loop must be boolean\n");
                yyerror();
            }
            backpatch($3.trueList, $5.quad);
            backpatch($13.nextList, $8.quad);
            backpatch($14.nextList, $8.quad);
            $$.nextList = $6.falseList;
            backpatch($6.trueList, $12.quad);
            backpatch($9.trueList, $5.quad);
            backpatch($10.nextList, $5.quad);
            printf("PARSER: Done processing for\n");
        }
    | '{' statement_list '}'
        {
	    printf("PARSER: Processing statement block.\n");
	    $$.nextList = $2.nextList;
	    printf("PARSER: Done processing statement block.\n");
        }
    | '{' '}'
        {	    
	    printf("PARSER: Processing empty block.\n");
	    $$.nextList = NULL;
	    printf("PARSER: Done processing empty block.\n");
        }
    ;

unmatched_statement
    : IF '(' assignment ')' marker statement
        {
	    printf("PARSER: Processing unmatched if then.\n");
	    backpatch($3.trueList,$5.quad);
	    $$.nextList = mergelists($3.falseList,$6.nextList);
	    printf("PARSER: Done processing unmatched if then.\n");
        }
    | WHILE marker '(' assignment ')' marker unmatched_statement jump_marker
        {
	    printf("PARSER: Processing unmatched while.\n");
	    backpatch($4.trueList,$6.quad);
	    $$.nextList = $4.falseList;
	    backpatch($7.nextList,$2.quad);
	    backpatch($8.nextList,$2.quad);
	    printf("PARSER: Done processing unmatched while.\n");
        }
    | FOR '(' assignment ';' marker assignment ';' marker assignment jump_marker ')' marker unmatched_statement jump_marker
        {
            printf("PARSER: Processing unmatched for\n");
            if(ST_BOOL == $3.type || ST_BOOL == $9.type) {
                printf("error, no boolean statements allowed as 1st or 3rd assignment in for loop\n");
                yyerror();
            }
            if(ST_BOOL != $6.type) {
                printf("error, 2nd argument of for loop must be boolean\n");
                yyerror();
            }
            backpatch($3.trueList, $5.quad);
            backpatch($13.nextList, $8.quad);
            backpatch($14.nextList, $8.quad);
            $$.nextList = $6.falseList;
            backpatch($6.trueList, $12.quad);
            backpatch($9.trueList, $5.quad);
            backpatch($10.nextList, $5.quad);
            printf("PARSER: Done processing for\n");
        }

    | IF '(' assignment ')' marker matched_statement jump_marker ELSE marker unmatched_statement
        {
	    printf("PARSER: Processing unmatched if then else.\n");
	    backpatch($3.trueList,$5.quad);
	    backpatch($3.falseList,$9.quad);
	    $$.nextList = mergelists($7.nextList,$10.nextList);
	    $$.nextList = mergelists($$.nextList,$6.nextList);
	    printf("PARSER: Done processing unmatched if then else.\n");
        }
    ;

assignment
    : expression
        {
            printf("PARSER: found expression as assignment %s\n", $1.value);
            $$=$1;
        }
    | id '=' expression
        {
            int destType = getSymbolType($1);
        	if(destType == 0){
        		printf("ERROR: Not in scope");
        	}
            if(destType != $3.type) {
                printf("Type error on line: %d\n", yylineno);
                yyerror();
            }
            printf("PARSER: found real assignment\n");
            sprintf(quadBuffer,"%s := %s",$1,$3.value);
            genquad(quadBuffer);
            $$.type = destType;
            $$.trueList = $3.trueList;
            $$.cType = C_VARIABLE;
            $$.value = $1;
        }
    ;

expression
    : INC_OP expression
        {
	    printf("PARSER: Processing increment.");
	    if($2.type != ST_INT){
		    printf("ERROR: Increment not allowed for types different than Integer.\n");
		    yyerror();
	    }
	    //Create a variable if needed
	    if($2.cType != C_VARIABLE){
		    char *var = nextIntVar();
		    sprintf(quadBuffer,"%s := %s",var,$2.value);
		    genquad(quadBuffer);
		    free($2.value);
		    $2.value = var;
		    $2.type = ST_INT;
		    $2.cType = C_VARIABLE;
	    }
            sprintf(quadBuffer,"%s := %s + 1",$2.value,$2.value);
            genquad(quadBuffer);
            //Set the attributes
            $$ = $2;
            $$.trueList = NULL;
            $$.falseList = NULL;
	    printf("PARSER: Done processing increment.");
        }
    | DEC_OP expression
        {
	    printf("PARSER: Processing decrement.");
	    if($2.type != ST_INT){
		    printf("ERROR: Decrement not allowed for types different than Integer.\n");
		    yyerror();
	    }
	    //Create a variable if needed
	    if($2.cType != C_VARIABLE){
		    char *var = nextIntVar();
		    sprintf(quadBuffer,"%s := %s",var,$2.value);
		genquad(quadBuffer);
		    free($2.value);
		    $2.value = var;
		    $2.type = ST_INT;
		    $2.cType = C_VARIABLE;
	    }
            sprintf(quadBuffer,"%s := %s - 1",$2.value,$2.value);
            genquad(quadBuffer);
            //Set the attributes
            $$ = $2;
            $$.trueList = NULL;
            $$.falseList = NULL;
	    printf("PARSER: Done processing decrement.");
        }
    | expression LOG_OR marker expression
        {
            if(ST_BOOL != $1.type) {
                sprintf(quadBuffer, "IF (%s <> 0) GOTO", $1.value);
                $1.trueList = addToList(NULL, genquad(quadBuffer));
                sprintf(quadBuffer, "GOTO");
                $1.falseList = addToList(NULL, genquad(quadBuffer));
            }
            if(ST_BOOL != $4.type) {
                sprintf(quadBuffer, "IF (%s <> 0) GOTO", $4.value);
                $4.trueList = addToList(NULL, genquad(quadBuffer));
                sprintf(quadBuffer, "GOTO");
                $4.falseList = addToList(NULL, genquad(quadBuffer));
            }
            $$.trueList = mergelists($1.trueList, $4.trueList);
            backpatch($1.falseList, $3.quad);
            $$.falseList = $4.falseList;
            $$.type = ST_BOOL;
	    /*printf("PARSER: Processing logical or.\n");
	    if($1.type != ST_BOOL){
		if($1.type != ST_INT && $1.type != ST_REAL){
		    printf("ERROR: Only Bool, Int and Float allowed in logical expressions!\n");
		    yyerror();
		}
		char* var = nextBoolVar();
		//sprintf(quadBuffer,"%s = FALSE",var);
		//genquad(quadBuffer);
		sprintf(quadBuffer,"IF (%s = 0) GOTO",$1.value);
		$1.falseList = addToList(NULL,genquad(quadBuffer));
		//sprintf(quadBuffer,"%s = TRUE",var);
		//genquad(quadBuffer);
		sprintf(quadBuffer,"GOTO",$1.value);
		$1.trueList = addToList(NULL,genquad(quadBuffer));
		free($1.value);
		$1.value = var;
		$1.type = ST_BOOL;
		$1.cType = C_VARIABLE;
		$3.quad = nextquad();
	    }
	    if($4.type != ST_BOOL){
		if($4.type != ST_INT && $4.type != ST_REAL){
		    printf("ERROR: Only Bool, Int and Float allowed in logical expressions!\n");
		    yyerror();
		}
		$3.quad = nextquad();
		char* var = nextBoolVar();
		//sprintf(quadBuffer,"%s = FALSE",var);
		//genquad(quadBuffer);
		sprintf(quadBuffer,"IF (%s = 0) GOTO",$4.value);
		$4.falseList = addToList(NULL,genquad(quadBuffer));
		//sprintf(quadBuffer,"%s = TRUE",var);
		//genquad(quadBuffer);
		sprintf(quadBuffer,"GOTO",$4.value);
		$4.trueList = addToList(NULL,genquad(quadBuffer));
		free($4.value);
		$4.value = var;
		$4.type = ST_BOOL;
		$4.cType = C_VARIABLE;
	    }
	    backpatch($1.falseList,$3.quad);
        //$$.type = ST_BOOL;
	    $$.trueList = mergelists($1.trueList,$4.trueList);
	    $$.falseList = $4.falseList;
	    printf("PARSER: Done processing logical or.\n");
        */
	    }
    | expression LOG_AND marker expression
        {
            if(ST_BOOL != $1.type) {
                sprintf(quadBuffer, "IF (%s <> 0) GOTO", $1.value);
                $1.trueList = addToList(NULL, genquad(quadBuffer));
                sprintf(quadBuffer, "GOTO");
                $1.falseList = addToList(NULL, genquad(quadBuffer));
            }
            if(ST_BOOL != $4.type) {
                sprintf(quadBuffer, "IF (%s <> 0) GOTO", $4.value);
                $4.trueList = addToList(NULL, genquad(quadBuffer));
                sprintf(quadBuffer, "GOTO");
                $4.falseList = addToList(NULL, genquad(quadBuffer));
            }
            $$.falseList = mergelists($1.falseList, $4.falseList);
            backpatch($1.trueList, $3.quad);
            $$.trueList = $4.trueList;
            $$.type = ST_BOOL;
        /*
	    printf("PARSER: Processing logical and.\n");
	    if($1.type != ST_BOOL){
		if($1.type != ST_INT && $1.type != ST_REAL){
		    printf("ERROR: Only Bool, Int and Float allowed in logical expressions!\n");
		    yyerror();
		}
		char* var = nextBoolVar();
		//sprintf(quadBuffer,"%s = FALSE",var);
		//genquad(quadBuffer);
		sprintf(quadBuffer,"IF (%s = 0) GOTO",$1.value);
		$1.falseList = addToList(NULL,genquad(quadBuffer));
		//sprintf(quadBuffer,"%s = TRUE",var);
		//genquad(quadBuffer);
		sprintf(quadBuffer,"GOTO",$1.value);
		$1.trueList = addToList(NULL,genquad(quadBuffer));
		free($1.value);
		$1.value = var;
		$1.type = ST_BOOL;
		$1.cType = C_VARIABLE;
		$3.quad = nextquad();
	    }
	    if($4.type != ST_BOOL){
		if($4.type != ST_INT && $4.type != ST_REAL){
		    printf("ERROR: Only Bool, Int and Float allowed in logical expressions!\n");
		    yyerror();
		}
		$3.quad = nextquad();
		char* var = nextBoolVar();
		//sprintf(quadBuffer,"%s = FALSE",var);
		//genquad(quadBuffer);
		sprintf(quadBuffer,"IF (%s = 0) GOTO",$4.value);
		$4.falseList = addToList(NULL,genquad(quadBuffer));
		//sprintf(quadBuffer,"%s = TRUE",var);
		//genquad(quadBuffer);
		sprintf(quadBuffer,"GOTO",$4.value);
		$4.trueList = addToList(NULL,genquad(quadBuffer));
		free($4.value);
		$4.value = var;
		$4.type = ST_BOOL;
		$4.cType = C_VARIABLE;
	    }
	    backpatch($1.trueList,$3.quad);
        //$$.type = ST_BOOL;
	    $$.falseList = mergelists($1.falseList,$4.falseList);
	    $$.trueList = $4.trueList;
	    printf("PARSER: Done processing logical and.\n");
        */
	  }
    | expression NOT_EQUAL expression
        {
	    printf("PARSER: Processing logical not equal.\n");
	    if($1.type != ST_INT && $1.type != ST_REAL){
		printf("ERROR: Only Integer, Float and Bool values allowed in comparsions.\n");
		yyerror();
	    }
            sprintf(quadBuffer,"IF (%s <> %s) GOTO",$1.value,$3.value);
	    $$.trueList = addToList(NULL, genquad(quadBuffer));
            sprintf(quadBuffer,"GOTO");
	    $$.falseList = addToList(NULL, genquad(quadBuffer));
	    $$.value = "TrueFalse Only!";
	    $$.type = ST_BOOL;
	    $$.cType = C_NONE;
	    printf("PARSER: Done processing logical not equal.\n");
        }
    | expression EQUAL expression
        {
	    printf("PARSER: Processing logical equal.\n");
	    if($1.type != ST_INT && $1.type != ST_REAL){
		printf("ERROR: Only Integer, Float and Bool values allowed in comparsions.\n");
		yyerror();
	    }
            sprintf(quadBuffer,"IF (%s = %s) GOTO",$1.value,$3.value);
	    $$.trueList = addToList(NULL, genquad(quadBuffer));
            sprintf(quadBuffer,"GOTO");
	    $$.falseList = addToList(NULL, genquad(quadBuffer));
        // jefftest
        if(ST_BOOL == $1.type) {
            $$.trueList = mergelists($$.trueList, $1.trueList);
            $$.falseList = mergelists($$.falseList, $1.falseList);
        }
        if(ST_BOOL == $3.type) {
            $$.trueList = mergelists($$.trueList, $3.trueList);
            $$.falseList = mergelists($$.falseList, $3.falseList);
        }
	    $$.value = "TrueFalse Only!";
	    $$.type = ST_BOOL;
	    $$.cType = C_NONE;
	    printf("PARSER: Done processing logical equal.\n");
        }
    | expression GREATER_OR_EQUAL expression
        {
	    printf("PARSER: Processing logical greater or equal.\n");
	    if($1.type != ST_INT && $1.type != ST_REAL){
		printf("ERROR: Only Integer, Float and Bool values allowed in comparsions.\n");
		yyerror();
	    }
            sprintf(quadBuffer,"IF (%s >= %s) GOTO",$1.value,$3.value);
	    $$.trueList = addToList(NULL, genquad(quadBuffer));
            sprintf(quadBuffer,"GOTO");
	    $$.falseList = addToList(NULL, genquad(quadBuffer));
	    $$.value = "TrueFalse Only!";
	    $$.type = ST_BOOL;
	    $$.cType = C_NONE;
	    printf("PARSER: Done processing logical greater or equal.\n");
        }
    | expression LESS_OR_EQUAL expression
        {
	    printf("PARSER: Processing logical smaller or equal.\n");
	    if($1.type != ST_INT && $1.type != ST_REAL){
		printf("ERROR: Only Integer, Float and Bool values allowed in comparsions.\n");
		yyerror();
	    }
	    sprintf(quadBuffer,"IF (%s <= %s) GOTO",$1.value,$3.value);
	    $$.trueList = addToList(NULL, genquad(quadBuffer));
	    sprintf(quadBuffer,"GOTO");
	    $$.falseList = addToList(NULL, genquad(quadBuffer));
	    $$.value = "TrueFalse Only!";
	    $$.type = ST_BOOL;
	    $$.cType = C_NONE;
	    printf("PARSER: Done processing logical smaller or equal.\n");
        }
    | expression '>' expression
        {
	    printf("PARSER: Processing logical bigger.\n");
	    if($1.type != ST_INT && $1.type != ST_REAL){
		printf("ERROR: Only Integer, Float and Bool values allowed in comparsions.\n");
		yyerror();
	    }
	    sprintf(quadBuffer,"IF (%s > %s) GOTO",$1.value,$3.value);
	    $$.trueList = addToList(NULL, genquad(quadBuffer));
	    sprintf(quadBuffer,"GOTO");
	    $$.falseList = addToList(NULL, genquad(quadBuffer));
	    $$.value = "TrueFalse Only!";
	    $$.type = ST_BOOL;
	    $$.cType = C_NONE;
	    printf("PARSER: Done processing logical bigger.\n");
        }
    | expression '<' expression
        {
	    printf("PARSER: Processing logical smaller.\n");
	    if($1.type != ST_INT && $1.type != ST_REAL){
		printf("ERROR: Only Integer, Float and Bool values allowed in comparsions.\n");
		yyerror();
	    }
	    sprintf(quadBuffer,"IF (%s < %s) GOTO",$1.value,$3.value);
	    $$.trueList = addToList(NULL, genquad(quadBuffer));
	    sprintf(quadBuffer,"GOTO");
	    $$.falseList = addToList(NULL, genquad(quadBuffer));
	    $$.value = "TrueFalse Only!";
	    $$.type = ST_BOOL;
	    $$.cType = C_NONE;
	    printf("PARSER: Done processing logical smaller.\n");
        }
    | expression SHIFTLEFT expression
        {
	    printf("PARSER: Processing left shift.\n");
	    if($1.type != ST_INT && $1.type!= ST_REAL &&  $3.type != ST_INT){
		printf("ERROR: Only integer and float values allowed when shifting.\n");
		yyerror();
	    }
	    
            char* var = NULL;
            char* shiftVar = nextIntVar();
            switch($1.type){
            	case ST_INT: var = nextIntVar();break;
            	case ST_REAL:var = nextFloatVar();break;
            }
            char buffer[50];
            sprintf(quadBuffer, "%s := %s", shiftVar, $3.value);
            genquad(quadBuffer);
            sprintf(quadBuffer, "%s := %s", var, $1.value);
            genquad(quadBuffer);
            sprintf(quadBuffer, "IF (%s <= 0) GOTO %d", shiftVar, nextquad()+4);
            genquad(quadBuffer);
            sprintf(quadBuffer, "%s := %s * 2", var, var);
            genquad(quadBuffer);
            sprintf(quadBuffer, "%s := %s - 1", shiftVar, shiftVar);
            genquad(quadBuffer);
            sprintf(quadBuffer, "GOTO %d", nextquad()-3);
            genquad(quadBuffer);


            $$.value = var;
            $$.type = $1.type;
            $$.cType = C_VARIABLE;
	    $$.trueList = NULL;
	    $$.falseList = NULL;
	    printf("PARSER: Done processing left shift.\n");
        }
    | expression '+' expression
        {
	    printf("PARSER: Processing addition.\n");
	    if($1.type != ST_INT && $1.type!= ST_REAL &&  $3.type != ST_INT && $3.type != ST_REAL){
		printf("ERROR: Only integer and float values allowed when adding numbers.\n");
		yyerror();
	    }
	    int type = 0;
	    if($1.type == $3.type){
		type = $1.type;
	    }
	    else{
		type = ST_REAL;
	    }
	    
	    char* var = NULL;
            switch(type){
            	case ST_INT: var = nextIntVar();break;
            	case ST_REAL:var = nextFloatVar();break;
            }
            char buffer[50];
            sprintf(quadBuffer,"%s := %s + %s",var,$1.value,$3.value);
            genquad(quadBuffer);
            $$.value = var;
            $$.type = type;
            $$.cType = C_VARIABLE;
	    $$.trueList = NULL;
	    $$.falseList = NULL;
	    printf("PARSER: Done processing addition.\n");
        }
    | expression '-' expression
        {
	    printf("PARSER: Processing substraction.\n");
	    if($1.type != ST_INT && $1.type!= ST_REAL &&  $3.type != ST_INT && $3.type != ST_REAL){
		printf("ERROR: Only integer and float values allowed when substracting numbers.\n");
		yyerror();
	    }
	    int type = 0;
	    if($1.type == $3.type){
		type = $1.type;
	    }
	    else{
		type = ST_REAL;
	    }
	    
	    char* var = NULL;
            switch(type){
            	case ST_INT: var = nextIntVar();break;
            	case ST_REAL:var = nextFloatVar();break;
            }
            char buffer[50];
            sprintf(quadBuffer,"%s := %s - %s",var,$1.value,$3.value);
            genquad(quadBuffer);
            $$.value = var;
            $$.type = type;
            $$.cType = C_VARIABLE;
	    $$.trueList = NULL;
	    $$.falseList = NULL;
	    printf("PARSER: Done processing substraction.\n");
        }
    | expression '*' expression
        {
	    printf("PARSER: Processing multiplication.\n");
	    if($1.type != ST_INT && $1.type!= ST_REAL &&  $3.type != ST_INT && $3.type != ST_REAL){
		printf("ERROR: Only integer and float values allowed when multiplicating numbers.\n");
		yyerror();
	    }
	    int type = 0;
	    if($1.type == $3.type){
		type = $1.type;
	    }
	    else{
		type = ST_REAL;
	    }
	    
	    char* var = NULL;
            switch(type){
            	case ST_INT: var = nextIntVar();break;
            	case ST_REAL:var = nextFloatVar();break;
            }
            char buffer[50];
            sprintf(quadBuffer,"%s := %s * %s",var,$1.value,$3.value);
            genquad(quadBuffer);
            $$.value = var;
            $$.type = type;
            $$.cType = C_VARIABLE;
	    $$.trueList = NULL;
	    $$.falseList = NULL;
	    printf("PARSER: Done processing multiplication.\n");
        }
    | expression '/' expression
        {
	    printf("PARSER: Processing division.\n");
	    if($1.type != ST_INT && $1.type!= ST_REAL &&  $3.type != ST_INT && $3.type != ST_REAL){
		printf("ERROR: Only integer and float values allowed when dividing numbers.\n");
		yyerror();
	    }
	    int type = 0;
	    if($1.type == $3.type){
		type = $1.type;
	    }
	    else{
		type = ST_REAL;
	    }
	    
	    char* var = NULL;
            switch(type){
            	case ST_INT: var = nextIntVar();break;
            	case ST_REAL:var = nextFloatVar();break;
            }
            char buffer[50];
            sprintf(quadBuffer,"%s := %s / %s",var,$1.value,$3.value);
            genquad(quadBuffer);
            $$.value = var;
            $$.type = type;
            $$.cType = C_VARIABLE;
	    $$.trueList = NULL;
	    $$.falseList = NULL;
	    printf("PARSER: Done processing division.\n");
        }
    | expression '%' expression
        {
	    printf("PARSER: Processing modulo.\n");
	    if($1.type != ST_INT && $1.type!= ST_REAL &&  $3.type != ST_INT && $3.type != ST_REAL){
		printf("ERROR: Only integer and float values allowed when caluclating mod.\n");
		yyerror();
	    }
	    int type = 0;
	    if($1.type == $3.type){
		type = $1.type;
	    }
	    else{
		type = ST_REAL;
	    }
	    
	    char* var = NULL;
            switch(type){
            	case ST_INT: var = nextIntVar();break;
            	case ST_REAL:var = nextFloatVar();break;
            }
            char buffer[50];
            sprintf(quadBuffer,"%s := %s \% %s",var,$1.value,$3.value);
            genquad(quadBuffer);
            $$.value = var;
            $$.type = type;
            $$.cType = C_VARIABLE;
	    $$.trueList = NULL;
	    $$.falseList = NULL;
	    printf("PARSER: Done processing modulo.\n");
        }
    | '!' expression
        {
	    printf("PARSER: Processing logical not.\n");
	    if($2.type != ST_BOOL){
		if($2.type != ST_INT && $2.type != ST_REAL){
		    printf("ERROR: Only Bool, Int and Float allowed in logical expressions!\n");
		    yyerror();
		}
		//char* var = nextBoolVar();
		//sprintf(quadBuffer,"%s = FALSE",var);
		//genquad(quadBuffer);
		sprintf(quadBuffer,"IF (%s <> 0) GOTO",$2.value);
		$$.falseList = addToList(NULL,genquad(quadBuffer));
		//sprintf(quadBuffer,"%s = TRUE",var);
		//genquad(quadBuffer);
		sprintf(quadBuffer,"GOTO",$2.value);
		$$.trueList = addToList(NULL,genquad(quadBuffer));
	    }
	    else{
	      $$ = $2;
	      $$.trueList = $2.falseList;
	      $$.falseList = $2.trueList;
	    }
	    printf("PARSER: Done processing logical not.\n");
	}
    | U_PLUS expression
        {
            if(ST_INT != $2.type && ST_REAL != $2.type) {
                yyerror();
            }
            $$ = $2;
        }
    | U_MINUS expression
        {
            $$ = $2;
            if(ST_INT == $2.type) {
                $$.value = nextIntVar();
            } else if (ST_REAL == $2.type) {
                $$.value = nextFloatVar();
            } else {
                yyerror();
            }
            sprintf(quadBuffer, "%s := -%s", $$.value, $2.value);
            genquad(quadBuffer);
       }
    | CONSTANT
        {
	    printf("PARSER: Processing constant.\n");
            $$.value = strdup(yytext);
            $$.trueList = NULL;
	    $$.falseList = NULL;
	    printf("PARSER: Done processing constant.\n");
            
        }
    | '(' expression ')'
        {
            printf("PARSER: Processing expression in parentheses.\n");
	    $$ = $2;
	    printf("PARSER: Done processing expression in parentheses.\n");
        }
    | id '(' exp_list ')'
        {
	    printf("PARSER: Processing function call with parameters.\n");
            int varType = getFunctionType($1);
            if(varType == 0){
            	printf("ERROR: Function %s not defined!\n",$1);
		yyerror();
            }
            char* var = NULL;
            switch(varType){
            case SIT_BOOL:
                var = nextBoolVar();
                $$.type = ST_BOOL;
                break;
            case SIT_REAL:
                var = nextFloatVar();
                $$.type = ST_REAL;
                break;
            case SIT_INT:
                var = nextIntVar();
                $$.type = ST_INT;
                break;
            case SIT_NONE:
                $$.type = ST_NONE;
                break;
            }
	    $$.value = var;
	    $$.cType = C_VARIABLE;
	    checkAndGenerateParams($3.queue,$1,$3.count);
            sprintf(quadBuffer,"%s := CALL %s, %d",var,$1,$3.count);
            genquad(quadBuffer);
	    printf("PARSER: Done processing function call with parameters.\n");
        }
    | id '('  ')'
        {
	    printf("PARSER: Processing function call.\n");
            int varType = getFunctionType($1);
            if(varType == 0){
            	printf("ERROR: Function %s not defined!\n",$1);
		yyerror();
            }
            char* var = NULL;
            switch(varType){
            case SIT_BOOL:
                var = nextBoolVar;
                $$.type = ST_BOOL;
                break;
            case SIT_REAL:
                var = nextFloatVar;
                $$.type = ST_REAL;
                break;
            case SIT_INT:
                var = nextIntVar;
                $$.type = ST_INT;
                break;
            case SIT_NONE:
                $$.type = ST_NONE;
                break;
            }
	    $$.value = var;
	    $$.cType = C_VARIABLE;
	    checkAndGenerateParams(NULL,$1,0);
            sprintf(quadBuffer,"%s := CALL %s, %d",var,$1,0);
            genquad(quadBuffer);
	    printf("PARSER: Done processing function call.\n");
        }
    | id
        {
	    printf("PARSER: Processing identifier.\n");
	    int varType = getSymbolType($1);
            if(varType == 0){
            	printf("ERROR: Variable %s not in scope!\n",$1);
		yyerror();
            }
	    $$.value = $1;
	    $$.type = varType;
	    $$.cType = C_VARIABLE;
	    printf("PARSER: Done processing identifier.\n");
        }
    ;

exp_list
    : expression
        {
	    printf("PARSER: Processing expression list.\n");
	    if($1.type != ST_INT && $1.type != ST_REAL){
		printf("ERROR: Only Integer and Float are allowed as parameter types.\n");
		yyerror();
	    }
	    $$.queue = addSymbolToParameterQueue(NULL,$1.value,$1.type);
	    $$.count = 1;
	    printf("PARSER: Done processing expression list.\n");
        }
    | exp_list ',' expression
        {
	    printf("PARSER: Processing expression list.\n");
	      if($3.type != ST_INT && $3.type != ST_REAL){
		  printf("ERROR: Only Integer and Float are allowed as parameter types.\n");
		  yyerror();
	      }
	      $$.queue = addSymbolToParameterQueue($1.queue,$3.value,$3.type);
	      $$.count = $1.count + 1;
	    printf("PARSER: Done processing expression list.\n");
        }
    ;

id
    : IDENTIFIER
        {
            printf("PARSER: found identifier %s\n", $1);
            $$ = strdup(yytext);
        }
    ;
marker
	: {	
	      printf("PARSER: Generating marker.\n");
	      $$.quad = nextquad();
	      printf("PARSER: Done with the marker.\n");
	};
jump_marker
	: {
	      printf("PARSER: Generating jump marker.\n");
	      $$.quad = nextquad();
	      sprintf(quadBuffer,"GOTO");
	      $$.nextList = addToList(NULL, genquad(quadBuffer));
	      printf("PARSER: Done with the jump marker.\n");
   };
%%
