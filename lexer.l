%{
	#include <stdio.h>
	#include <stdlib.h>
	#include <string.h>
	#include "parser.tab.h"
%}

%option noyywrap

%%

"int" {return TYPE_INT;}
"if" {return IF;}
"else" {return ELSE;}
"while" {return WHILE;}
"return" {return RETURN;}

"==" {return EQ;}
"!=" {return NEQ;}
"<=" {return LE;}
">=" {return GE;}

[0-9]+	{
		yylval.num_val = atoi(yytext);
		return NUMBER;
	}

[a-zA-Z_][a-zA-Z0-9_]* {
		yylval.str_val=strdup(yytext);
		return ID;
	}

[+\-*/=<>(){};,] {return yytext[0];}

[ \t\r\n]+ {}

. {printf("Unknown character: %s\n", yytext);}

%%
