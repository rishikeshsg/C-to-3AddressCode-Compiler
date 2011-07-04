#include "quadrupelcode.h"
#include "parser.tab.h"
#include <malloc.h>
#include <string.h>
#include <stdlib.h>

#define printError(_msg) { printf("Fehler: %s\n", _msg); }

CodeLineEntry *codeLines = NULL;
SymbolTableEntry *symbolTable = NULL;
SymbolTableEntry *queueHead = NULL;
CodeLineEntry *codeLineHead = NULL, *codeLineTail = NULL;

unsigned int funcOffset = 0;
extern int yylineno;
unsigned int globalOffset = 0;
unsigned int floatVarCount = 0;
unsigned int intVarCount = 0;
unsigned int boolVarCount = 0;
int currentLine = -1;

void yyerror() {
    printf("ERROR\n");
}

int main(void) {
    yyparse();
    FILE *ofile = fopen("quadcode.out", "w");
    printSymbolTable(ofile);
    printCode(ofile);
    fclose(ofile);
    return(0);
}

static const char* InternalTypeToString(SYMBOL_INTERNAL_TYPE type)
{
    switch(type)
    {
        case SIT_NONE:
            return "None";

        case SIT_INT:
            return "Int";

        case SIT_REAL:
            return "Real";

        case SIT_BOOL:
            return "Bool";

        default:
            printError("Unbekannter interner Typ!");
            return "FAIL";
    }
}


static const char* TypeToString(SYMBOL_TYPE type)
{
    switch(type)
    {
        case ST_FUNC:
            return "Func";

        case ST_PROC:
            return "Proc";

        case ST_MAIN:
            return "Main";

        case ST_ARRAY:
            return "Array";

        case ST_INT:
            return "Int";

        case ST_REAL:
            return "Real";

        case ST_BOOL:
            return "Bool";

        case ST_PROTO:
            return "Proto";

        default:
            printError("Unbekannter Typ!");
            return "FAIL";
    }
}

CodeLineEntry *genquad(char *code){
	printf("In genquad\n");
	fflush(stdout);
	printf("%s\n",code);
	//Create the element
	CodeLineEntry* newCodeLine = malloc(sizeof(CodeLineEntry));
	newCodeLine->code = strdup(code);
	newCodeLine->next = NULL;
	newCodeLine->gotoL = -1;
	//refresh the header/tail
	if(codeLineHead == NULL){
		codeLineHead = newCodeLine;
		codeLineTail = newCodeLine;
	}
	else{
		codeLineTail->next = newCodeLine;
		codeLineTail = newCodeLine;
	}
	currentLine++;
	//return a pointer to the new element
	return newCodeLine;
}

void backpatch(BackpatchList* list, int gotoL){
	printf("In backpatch with %d\n", gotoL);
	fflush(stdout);
	if(list == NULL){
		return;
	} else{
		BackpatchList* temp;
		while(list){
			if(list->entry != NULL){
				list->entry->gotoL = gotoL;
			}
			printf("backpatching: %s",list->entry->code);
			temp = list;
			list = list->next;
			free(temp);
		}
	}
}

BackpatchList* mergelists(BackpatchList* a, BackpatchList* b){
	printf("In mergelists\n");
	fflush(stdout);
	if(a != NULL && b == NULL){
		return a;
	}
	else if(a == NULL && b != NULL){
		return b;
	}
	else if(a == NULL && b == NULL){
		return NULL;
	}
	else{
		BackpatchList* temp = a;
		while(a->next){
			a = a->next;
		}
		a->next = b;
		return temp;
	}
}

BackpatchList* addToList(BackpatchList* list, CodeLineEntry* entry){
	printf("In addToList\n");
	fflush(stdout);
	if(entry == NULL){
		return list;
	}
	else if(list == NULL){
		BackpatchList* newEntry = malloc(sizeof(BackpatchList));
		newEntry->entry = entry;
		newEntry->next = NULL;
		return newEntry;
	}
	else{
		BackpatchList* newEntry = malloc(sizeof(BackpatchList)), *temp = list;
		newEntry->entry = entry;
		newEntry->next=NULL;
		while(list->next){
			list = list->next;
		}
		list->next = newEntry;
		return temp;
	}
}

SymbolTableEntry* addSymbol(const char *name,
               SYMBOL_TYPE type,
               SYMBOL_INTERNAL_TYPE internalType,
               unsigned long offsetOrSize,
               unsigned long line,
               long index1,
               long index2,
               char *parent,
               unsigned long parameter)
{
    if(name == NULL || strcmp(name, "") == 0)
    {
        printError("Parameter \"name\" nicht korrekt\"");

        return 0;
    }

    if(parent != NULL && strcmp(parent, "None") == 0)
    {
        printError("\"parent\" darf nicht \"None\" sein, bitte f�r diesen Zweck PARENT_NONE benutzen!");

        return 0;
    }

    SymbolTableEntry *symbol = malloc(sizeof(SymbolTableEntry));

    symbol->name         = strdup(name);
    symbol->type         = type;
    symbol->internalType = internalType;
    symbol->offsetOrSize = offsetOrSize;
    symbol->line         = line;
    symbol->index1       = index1;
    symbol->index2       = index2;
    symbol->parent       = (parent == PARENT_NONE ? NULL : strdup(parent));
    symbol->parameter    = parameter;
    symbol->next         = NULL;

    SymbolTableEntry *tail = symbolTable;
    if(tail)
    {
        while(tail->next) tail = tail->next;

        tail->next = symbol;
    }
    else
    {
        symbolTable = symbol;
    }

    return symbol;
}


bool printCode(FILE *outputFile)
{
    CodeLineEntry *codeLine = codeLineHead;

    if(codeLine == NULL)
    {
        printError("Es gibt keine Codezeilen!");

        return false;
    }

    unsigned long lineNumber = 0;

    if(fprintf(outputFile, "\n\nCODE\n----\n\n") <= 0)
    {
        printError("Schreibfehler");

        return false;
    }

    while(codeLine)
    {
    	int ret;
    	//No goto
    	if(codeLine->gotoL == -1){
    		ret = fprintf(outputFile, "%-4lu %s\n", lineNumber, codeLine->code);
    	}
    	//goto
    	else{
    		ret = fprintf(outputFile, "%-4lu %s %d\n", lineNumber, codeLine->code, codeLine->gotoL);
    	}
        if(ret <= 0)
        {
            printError("Schreibfehler");

            return false;
        }

        codeLine = codeLine->next;
        ++lineNumber;
    }

    return true;
}


bool printSymbolTable(FILE *outputFile)
{
    if(symbolTable == NULL)
    {
        printError("Symboltabelle ist leer!");

        return false;
    }

    int ret = fprintf(outputFile, "SYMBOLS\n"
                                  "-------------\n"
                                  ""
                                  "Name            Type    Int_Typ    Offset/Size    Line    Index1    Index2    Parent          Parameter\n"
                                  "-------------------------------------------------------------------------------------------------------\n");

    if(ret <= 0)
    {
        printError("Schreibfehler");

        return false;
    }

    SymbolTableEntry *symbol = symbolTable;

    while(symbol)
    {
        ret = fprintf(outputFile,
                      "%-15s %-7s %-10s %-14lu %-7lu %-9ld %-9ld %-15s %lu\n",
                      symbol->name,
                      TypeToString(symbol->type),
                      InternalTypeToString(symbol->internalType),
                      symbol->offsetOrSize,
                      symbol->line,
                      symbol->index1,
                      symbol->index2,
                      symbol->parent == NULL ? "None" : symbol->parent,
                      symbol->parameter);

        if(ret <= 0)
        {
            printError("Schreibfehler");

            return false;
        }

        symbol = symbol->next;
    }

    return true;
}
/**
 * Clear the queue if function was only a prototype.
 */
void clearQueue() {
    SymbolTableEntry *cur;
    while(queueHead != NULL) {
        cur = queueHead;

        queueHead = queueHead->next;
        free(cur);
    }
}


void freeCodeLinesAndSymbolTable()
{
    CodeLineEntry *codeLine = codeLines;

    while(codeLine)
    {
        CodeLineEntry *next = codeLine->next;

        free(codeLine->code);
        free(codeLine);

        codeLine = next;
    }
    
    codeLines = NULL;

    SymbolTableEntry *symbol = symbolTable;

    while(symbol)
    {
        SymbolTableEntry *next = symbol->next;

        free(symbol->name);
        free(symbol->parent);
        free(symbol);

        symbol = next;
    }
    
    symbolTable = NULL;
}

/**
 *
 */
SymbolTableEntry* addSymbolToParameterQueue(SymbolTableEntry* queue, char *name, SYMBOL_TYPE type) {
    SymbolTableEntry *symbol = malloc(sizeof(SymbolTableEntry));
    symbol->name         = strdup(name);
    symbol->type         = type;
    symbol->next = false;
    if (queue == NULL) {
        return symbol;
    } else {
        SymbolTableEntry *entry = queue;
        while (entry->next) {
            entry = entry->next;
        }
        entry->next = symbol;
        return queue;
    }
}

/**
 * Found symbols are added to a queue and then transferred to the symbol table when
 * the parent is known.
 */
void addSymbolToQueue(char *name, SYMBOL_TYPE type, unsigned long param_no) {
    SymbolTableEntry *symbol = malloc(sizeof(SymbolTableEntry));
    symbol->name         = strdup(name);
    symbol->type         = type;
    switch(type){
		case ST_INT: symbol->offsetOrSize = 4;break;
		case ST_REAL: symbol->offsetOrSize = 8;break;
		case ST_BOOL: symbol->offsetOrSize = 1;break;
		default: symbol->offsetOrSize = 4;
    }
    symbol->parameter = param_no;
    
    if (queueHead == NULL) {
        queueHead = symbol;
    } else {
        SymbolTableEntry *entry = queueHead;
        while (entry->next) {
            if(0 == strcmp(name, entry->name)) {
                // equally named variable already exists in this scope
                printf("ERROR: doubled variable declaration for %s on line %d\n", name, yylineno);
                exit(1);
            }
            entry = entry->next;
        }
        entry->next = symbol;
        symbol->next = NULL;
    }
}

void addFunctionPrototype(char *name, unsigned int parameter_count, SYMBOL_INTERNAL_TYPE ret_type){
	//Pointer to the symbol table
	SymbolTableEntry *symTable = symbolTable;
	//search for existing entries
	if(0 == strcasecmp(name, "main")){
		printf("Prototype for main not allowed!");
		exit(-1);
	}
	if(symTable != NULL){
		while(symTable){
			if( (symTable->type == ST_PROTO || symTable->type == ST_MAIN || symTable->type == ST_FUNC) && (0 == strcmp(name,symTable->name))){
				printf("Duplicate function definition for %s", symTable->name);
				exit(-1);
			}
			symTable = symTable->next;
		}
	}
	//Add the prototype to the symbol table
	addSymbol(name,ST_PROTO,ret_type,0,0,0,0,NULL,parameter_count);
	//Add the queued parameters to the function
	if(queueHead == NULL && parameter_count != 0){
		printf("Parameter count mismatch.");
		exit(-1);
	}
	else{
		int paramCount = 0;
		//Add the elements
		SymbolTableEntry *queueElement = queueHead;
		while(queueElement){
			queueElement->parent = name;
			queueElement->parameter = ++paramCount;
			addSymbol(queueElement->name,queueElement->type,
					queueElement->internalType,queueElement->offsetOrSize,
					queueElement->line,queueElement->index1,queueElement->index2,
					queueElement->parent,queueElement->parameter);
			queueElement = queueElement->next;
		}
		clearQueue();
	}
}

/**
 * Adds the symbol queue to the symbol table after function was found.
 */
void addFunction(char *name, unsigned int parameter_count, SYMBOL_INTERNAL_TYPE ret_type, int line) {
    SymbolTableEntry *symTable = symbolTable;
    SymbolTableEntry *prototype = NULL;
	int i=0;
	unsigned int internalOffset = 0;
    //table not empty
    if(symTable != NULL){
    	//search for the prototype
		while(symTable){
			if( symTable->type == ST_PROTO && 0 == strcasecmp(name,symTable->name)){
				prototype = symTable;
				break;
			}
			symTable = symTable->next;
		}
	}
    //Dealing with the main function
    if(strcmp(name, "main") == 0){
    	SymbolTableEntry *newEntry;
    	if(parameter_count != 0){
    		printf("Parameter for main not allowed!");
    		exit(-1);
    	}
    	else if(ret_type != SIT_INT){
    		printf("Main must return an integer!");
    		exit(-1);
    	}
    	else{
    		SymbolTableEntry *queueElement = queueHead;
    		//Add all variables
                int s = 0;
                printf("FUNC: %s\n", name);
    		while(queueElement){
                        printf("FUNC: par %s - %d\n", queueElement->name, queueElement->offsetOrSize);
    			//update the size
    			//remember it
    			int size = queueElement->offsetOrSize;
    			queueElement->offsetOrSize = internalOffset;
    			//increase internal and global offset
    			internalOffset+=size;
    			globalOffset+=size;
                        s+=size;
    			//Link the new parent
    			queueElement->parent = name;
    			queueElement->parameter = 0;
    			addSymbol(queueElement->name,queueElement->type,
    					queueElement->internalType,queueElement->offsetOrSize,
    					queueElement->line,queueElement->index1,queueElement->index2,
    					queueElement->parent,queueElement->parameter);
    			queueElement = queueElement->next;
    		}
        	newEntry = addSymbol(name,ST_MAIN,ret_type,s,line,0,0,NULL,0);
    		//clear the queue
    		clearQueue();
    	}
    	/*
    	//make main the first entry
		if(symbolTable != newEntry){
			SymbolTableEntry *temp = symbolTable;
			while(temp->next != newEntry){
				temp = temp->next;
			}
			temp->next = NULL;
			newEntry->next = symbolTable;
			symbolTable = newEntry;
		}
		*/
	}
    //prototype not found
    else if(!prototype){
    	//Add the queued parameters to the function
    	if(queueHead == NULL && parameter_count != 0){
    		printf("Parameter count mismatch.");
    		exit(-1);
    	}
    	else{
    		int paramCount = 0;
                int s = 0;
    		//Add the elements
                printf("FUNC: %s\n", name);
    		SymbolTableEntry *queueElement = queueHead;
    		while(queueElement){
    			//update the size
    			//remember it
                        printf("FUNC: par %s, %d\n", queueElement->name, queueElement->offsetOrSize);
    			int size = queueElement->offsetOrSize;
                        s += size;
    			queueElement->offsetOrSize = internalOffset;
    			//increase internal and global offset
    			internalOffset+=size;
    			globalOffset+=size;
    			//Link the new parent
    			queueElement->parent = name;
    			queueElement->parameter = (paramCount<parameter_count) ? ++paramCount : 0;
    			addSymbol(queueElement->name,queueElement->type,
    					queueElement->internalType,queueElement->offsetOrSize,
    					queueElement->line,queueElement->index1,queueElement->index2,
    					queueElement->parent,queueElement->parameter);
    			queueElement = queueElement->next;
    		}
    	    //Add the function to the symbol table
    	    SymbolTableEntry *newEntry = addSymbol(name,ST_FUNC,ret_type,s,line,0,0,NULL,parameter_count);
    	    clearQueue();
    	}
    }
    //prototype found
    else{
    	//Make it a real function
    	prototype->type = ST_FUNC;
    	//update the offset
    	//prototype->offsetOrSize = globalOffset;
	prototype->line = line;
    	if(queueHead == NULL && parameter_count != 0){
    		printf("Parameter count mismatch.");
    		exit(-1);
    	}
    	else{
    		//compare the parameter count
    		if(prototype->parameter != parameter_count){
    			printf("Wrong parameter count for function %s\n",name);
    			exit(-1);
    		}
		int s = 0;
    		//check parameter type
    		SymbolTableEntry *currentEntry = symbolTable;
    		for(i = 0;i<parameter_count;++i){
    			while(currentEntry->parent == NULL){
    				currentEntry=currentEntry->next;
    				if(currentEntry->parent != NULL && 0 == strcmp(currentEntry->parent,name)){
    					break;
    				}
    			}
    			if(currentEntry->type != queueHead->type){
        			printf("Parameter type mismatch in function %s\n",name);
        			exit(-1);
    			}
    			//update the size
    			//remember it
    			int size = currentEntry->offsetOrSize;
			s+=size;
			fprintf(stderr,"%s:\tSize: %d,internalOffset: %d\n",currentEntry->name,size,internalOffset);
    			currentEntry->offsetOrSize = internalOffset;
    			//increase internal and global offset
    			internalOffset+=size;
    			globalOffset+=size;
    			//remove the element from the queue
    			SymbolTableEntry *toBeDeleted = queueHead;
    			queueHead = queueHead->next;
    			free(toBeDeleted);
			currentEntry = currentEntry->next;
    		}
    		//Add the elements
    		SymbolTableEntry *queueElement = queueHead;
    		while(queueElement){
    			//update the size
    			//remember it
    			int size = queueElement->offsetOrSize;
    			queueElement->offsetOrSize = internalOffset;
    			//increase internal and global offset and function offset/size
    			internalOffset+=size;
    			globalOffset+=size;
                        s+=size;
    			//link the new parent
    			queueElement->parent = name;
    			queueElement->parameter = 0;
    			addSymbol(queueElement->name,queueElement->type,
    					queueElement->internalType,queueElement->offsetOrSize,
    					queueElement->line,queueElement->index1,queueElement->index2,
    					queueElement->parent,queueElement->parameter);
    			queueElement = queueElement->next;
    		}
                prototype->offsetOrSize = s;
    		clearQueue();
    	}
    }

}

/**
 * This function checks if a used symbol is already declared and exits the program
 * if not.
 */
int getSymbolType(char *name) {
    SymbolTableEntry *cur;
    
    cur = queueHead;
    while(cur != NULL) {
        if(0 == strcmp(name, cur->name)) {
			// return variable type
			return(cur->type);
        } else {
            cur = cur->next;
        }
    }

    // only reaches here when symbol is not in scope
    return 0;
}

int getFunctionType(char *name){
	SymbolTableEntry *cur = symbolTable;
	while(cur != NULL){
		if((cur->type == ST_FUNC || cur->type == ST_PROTO) && 0 == strcmp(name,cur->name)){
			return cur->internalType;
		}
	}

	return 0;
}

char* nextFloatVar(){
    char buffer[10];
    sprintf(buffer,"f_%d",++floatVarCount);
    addSymbolToQueue(buffer, ST_REAL, 0);
    return strdup(buffer);
}

char* nextIntVar(){
    char buffer[10];
    sprintf(buffer,"i_%d",++intVarCount);
    addSymbolToQueue(buffer, ST_INT, 0);
    return strdup(buffer);
}

char* nextBoolVar(){
    char buffer[10];
    sprintf(buffer,"b_%d",++boolVarCount);
    addSymbolToQueue(buffer, ST_BOOL, 0);
    return strdup(buffer);
}

int checkAndGenerateParams(SymbolTableEntry* queue, char* name ,int parameterCount){
	//find the function
	char buffer[50];
	SymbolTableEntry *cur = symbolTable;
	while(cur != NULL){
		if((cur->type == ST_FUNC || cur->type == ST_PROTO) && 0 == strcmp(name,cur->name)){
			break;
		}
	}
	//found?
	if(cur == NULL)
		return -1;
	//search for the parameters
	int foundParams = 0;
	cur = symbolTable;
	do{
		while(cur != NULL){
			//found entry
			if(cur->parent != NULL && 0 == strcmp(name,cur->parent) && cur->parameter != 0){
				break;
			}
			cur = cur->next;
		}
		if(cur == NULL || queue == NULL){
			if(parameterCount == 0 && foundParams == 0)
				return 0;
			else
				return -2;
		}
		else if(cur->type != queue->type){
			return -3;
		}
		foundParams++;
		sprintf(buffer,"PARAM %s",queue->name);
		genquad(buffer);
		cur = cur->next;
		SymbolTableEntry *temp = queue;
		queue = queue->next;
		free(temp);
	}while(foundParams != parameterCount);
	return 0;
}

int nextquad(){
	return currentLine + 1;
}

SymbolTableEntry* lookup(char *name){
    SymbolTableEntry* cur = symbolTable;
    while(cur!=NULL){
	if(cur->name != NULL && 0 == strcmp(name, cur->name)){
	    break;
	}
	cur = cur->next;
    }
    return cur;
}
