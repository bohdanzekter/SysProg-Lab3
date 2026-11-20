%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>


typedef struct ASTNode {
    char* type;              
    char* val;               
    struct ASTNode* left;    
    struct ASTNode* right;   
    struct ASTNode* next;    
} ASTNode;

ASTNode* root = NULL;

ASTNode* make_node(char* type, char* val, ASTNode* left, ASTNode* right) {
    ASTNode* n = (ASTNode*)malloc(sizeof(ASTNode));
    n->type = strdup(type);
    n->val = val ? strdup(val) : NULL;
    n->left = left;
    n->right = right;
    n->next = NULL;
    return n;
}

int yylex(void);
void yyerror(const char *s);

%}

%union {
    int num_val;
    char* str_val;
    struct ASTNode* node;
}

%token <num_val> NUMBER
%token <str_val> ID
%token <str_val> TYPE_INT
%token IF ELSE WHILE RETURN
%token EQ NEQ LE GE

%right '='
%left EQ NEQ '<' '>' LE GE
%left '+' '-'
%left '*' '/'
%nonassoc UMINUS

%type <node> program stmt stmt_list expr

%%

program:
        stmt_list {root = $1;}
        ;

stmt_list:
        stmt {
                $$ = $1;
        }
        | stmt_list stmt {
                ASTNode* cur = $1;
                while (cur->next != NULL) {
			cur = cur->next;
                }
                cur->next = $2;
                $$ = $1;}
        ;

stmt:
        TYPE_INT ID ';' {$$ = make_node("VAR_DECL", $2, NULL, NULL);}

        | TYPE_INT ID '=' expr ';' {
                ASTNode* id_node = make_node("VAR", $2, NULL, NULL);
                $$ = make_node("VAR_DECL_INIT", "=", id_node, $4);}

        | ID '=' expr ';' {
                ASTNode* id_node = make_node("VAR", $1, NULL, NULL);
                $$ = make_node("ASSIGN", "=", id_node, $3); }

        | IF '(' expr ')' stmt {$$ = make_node("IF", NULL, $3, $5); }

        | IF '(' expr ')' stmt ELSE stmt {
                ASTNode* branches = make_node("BRANCHES", NULL, $5, $7);
                $$ = make_node("IF_ELSE", NULL, $3, branches); }

        | WHILE '(' expr ')' stmt {$$ = make_node("WHILE", NULL, $3, $5);}

        | '{' stmt_list '}' {$$ = make_node("BLOCK", NULL, $2, NULL);}
	
	| RETURN expr ';' { $$ = make_node("RETURN", NULL, $2, NULL); }
	
	| RETURN ';' { $$ = make_node("RETURN", NULL, NULL, NULL); }
	;


expr:
	NUMBER { 
		char buf[32];
		sprintf(buf, "%d", $1);
		$$ = make_node("NUM", buf, NULL, NULL); 
	}
	| ID {$$ = make_node("VAR", $1, NULL, NULL); }
	| expr '+' expr          { $$ = make_node("ADD", "+", $1, $3); }
	| expr '-' expr          { $$ = make_node("SUB", "-", $1, $3); }
	| expr '*' expr          { $$ = make_node("MUL", "*", $1, $3); }
	| expr '/' expr          { $$ = make_node("DIV", "/", $1, $3); }
	| expr '<' expr          { $$ = make_node("CMP", "<", $1, $3); }
	| expr '>' expr          { $$ = make_node("CMP", ">", $1, $3); }
	| expr EQ expr           { $$ = make_node("CMP", "==", $1, $3); }
	| expr NEQ expr          { $$ = make_node("CMP", "!=", $1, $3); }
	| expr LE expr           { $$ = make_node("CMP", "<=", $1, $3); }
	| expr GE expr           { $$ = make_node("CMP", ">=", $1, $3); }
	| '-' expr %prec UMINUS  { $$ = make_node("NEG", "-", $2, NULL); }
	| '(' expr ')'           { $$ = $2; }
	;

%%

void print_indent(FILE* out, int indent) {
	for (int i = 0; i < indent; i++) {
		fprintf(out, "    ");
	}
}

void gen_py_expr(ASTNode* node, FILE* out) {
	if (!node) return;
	if (strcmp(node->type, "NUM") == 0 || strcmp(node->type, "VAR") == 0) {
		fprintf(out, "%s", node->val);
	} else if (strcmp(node->type, "NEG") == 0) {
		fprintf(out, "(-");
		gen_py_expr(node->left, out);
		fprintf(out, ")");
	} else {
		fprintf(out, "(");
		gen_py_expr(node->left, out);
		fprintf(out, " %s ", node->val);
		gen_py_expr(node->right, out);
		fprintf(out, ")");
	}
}

void gen_py_stmt(ASTNode* node, FILE* out, int indent) {
	if (!node) return;

	if (strcmp(node->type, "BLOCK") == 0) {
		ASTNode* cur = node->left;
		if (!cur) {
			print_indent(out, indent);
			fprintf(out, "pass\n");
		} else {
			while (cur) {
				gen_py_stmt(cur, out, indent);
				cur = cur->next;
			}
		}
		return;
	}

	print_indent(out, indent);

	if (strcmp(node->type, "VAR_DECL") == 0) {
		fprintf(out, "%s = None\n", node->val);
	} else if (strcmp(node->type, "VAR_DECL_INIT") == 0 || strcmp(node->type, "ASSIGN") == 0) {
		fprintf(out, "%s = ", node->left->val);
		gen_py_expr(node->right, out);
		fprintf(out, "\n");
	} else if (strcmp(node->type, "IF") == 0) {
		fprintf(out, "if ");
	        gen_py_expr(node->left, out);
	        fprintf(out, ":\n");
	        gen_py_stmt(node->right, out, indent + 1);
	} else if (strcmp(node->type, "IF_ELSE") == 0) {
	        fprintf(out, "if ");
	        gen_py_expr(node->left, out);
	        fprintf(out, ":\n");
	        ASTNode* branches = node->right;
	        gen_py_stmt(branches->left, out, indent + 1);
	        print_indent(out, indent);
	        fprintf(out, "else:\n");
	        gen_py_stmt(branches->right, out, indent + 1);
	} else if (strcmp(node->type, "WHILE") == 0) {
	        fprintf(out, "while ");
	        gen_py_expr(node->left, out);
	        fprintf(out, ":\n");
	        gen_py_stmt(node->right, out, indent + 1);
	} else if (strcmp(node->type, "RETURN") == 0) {
	        fprintf(out, "print(\"Result:\", ");
	        if (node->left) {
		        gen_py_expr(node->left, out);
		} else {
			fprintf(out, "None");
		}	
	        fprintf(out, ")\n");
	}
}

void generate_python(ASTNode* root_node, const char* filename) {
	FILE* f = fopen(filename, "w");
	if (!f) {
	        perror("Failed to create Python output file");
	        return;
	}
	ASTNode* cur = root_node;
	while (cur) {
	        gen_py_stmt(cur, f, 0);
	        cur = cur->next;
	}
	fclose(f);
	printf("Target Python code successfully generated in '%s'\n", filename);
}


void ast_node_to_json(ASTNode* node, FILE* f) {
	if (!node) return;

	fprintf(f, "{\n");
	if (node->val) {
		fprintf(f, "  \"name\": \"%s (%s)\"", node->type, node->val);
	} else {
		fprintf(f, "  \"name\": \"%s\"", node->type);
	}

	int has_left = (node->left != NULL);
	int has_right = (node->right != NULL);

	if (has_left || has_right) {
		fprintf(f, ",\n  \"children\": [\n");
		if (has_left) {
			ast_node_to_json(node->left, f);
		}
		if (has_left && has_right) {
			fprintf(f, ",\n");
		}
		if (has_right) {
			ast_node_to_json(node->right, f);
		}
		fprintf(f, "\n  ]");
	}

	fprintf(f, "\n}");
}

void export_to_json(ASTNode* root_node, const char* filename) {
	FILE* f = fopen(filename, "w");
	if (!f) {
		perror("Failed to create JSON file");
		return;
	}

	fprintf(f, "{\n  \"name\": \"PROGRAM (root)\",\n  \"children\": [\n");
    
	ASTNode* cur = root_node;
	while (cur) {
		ast_node_to_json(cur, f);
		if (cur->next) {
			fprintf(f, ",\n");
		}
		cur = cur->next;
	}

	fprintf(f, "\n  ]\n}\n");
	fclose(f);
	printf("AST successfully exported to '%s'\n", filename);
}

void yyerror(const char *s) {
	fprintf(stderr, "Syntax error: %s\n", s);
}

int main(void) {
	printf("Enter code (Ctrl+D to end):\n");
    
	if (yyparse() == 0) {
	        printf("\nParsing completed.\n");
		export_to_json(root, "ast.json");
		generate_python(root, "output.py");	
	} else {
	        printf("\n Parsing terminated with errors.\n");
	}
    
	return 0;
}
