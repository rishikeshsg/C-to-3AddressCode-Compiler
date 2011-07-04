#include <stdlib.h>

// This is a demo programm

float questionmark (int x, int y);

int main (){
	
	int variable_1;
	int variable_2;
	float variable_3;

	variable_1 = 1;
	variable_2 = 2;
        variable_3 = -3.0;
	
	while (variable_1 <= 10 && 1){
	/*this loop runs how many times?*/
		
		variable_3 = questionmark (variable_1, variable_2);
			
		variable_2 = ++variable_1;
		variable_2 = variable_2 << 2;
	}
	// what is the value of variable_2
	
	if(! variable_3){
		return 0;
	}else{
		return 1;
	}
}

float questionmark (int x, int y){
//what makes this function

	float result;
	
	do{
		if (y/x){
			result = 1.0;
		}
		--y;
	}while( y < x || 0);

    for(x=0; x<10; ++x) {
        y=x;
        ++y;
    }
	
	//return result;
        if(x<=y && x+1>y || x==y) {
            return 1;
        } else {
            return 0;
        }
}



