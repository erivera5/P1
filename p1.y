//================================================================================
//  File Name: p1.y                                                              
//
//  Description: This file contains the parsing for our programming language, P1.
//
//  Emmanuel Rivera & Efren Martinez-Gomez
//
//  Feb 19, 2020
//================================================================================

%{
#include <stdio.h>
#include <string.h>
#include <errno.h>
#include <list>
#include <map>
  
#include "llvm/IR/LLVMContext.h"
#include "llvm/IR/Value.h"
#include "llvm/IR/Function.h"
#include "llvm/IR/Type.h"

#include "llvm/Bitcode/BitcodeReader.h"
#include "llvm/Bitcode/BitcodeWriter.h"
#include "llvm/Support/SystemUtils.h"
#include "llvm/Support/ToolOutputFile.h"
#include "llvm/IR/IRBuilder.h"
#include "llvm/Support/FileSystem.h"
ECE
using namespace llvm;
using namespace std;

extern FILE *yyin;
int yylex(void);
int yyerror(const char *);

// From main.cpp
extern char *fileNameOut;
extern Module *M;
extern LLVMContext TheContext;
extern Function *Func;
extern IRBuilder<> Builder;

// Used to lookup Value associated with ID
map<string,Value*> idLookup;
 
%}

%union {
  int num;
  char *id;
  Value * val;
  std::list<Value*> *vals;
}

%token ID NUM MINUS PLUS MULTIPLY DIVIDE LPAREN RPAREN SETQ SETF AREF MIN MAX MAKEARRAY ERROR

%left PLUS MINUS

%type <num> NUM
%type <id> ID
%type <val> expr token token_or_expr program
%type <vals> token_or_expr_list exprlist

%start program

%%

program : exprlist 
{  
/*
 *  This rule returns the most recently evaluated expr from the list. 
 */ 
  Value * tmp;
  tmp = $<vals>1->back();
  Builder.CreateRet(tmp);
  return 0;
}
;

exprlist:  exprlist expr
{
/*
 *  Additional action taken here to support an expr list. 
 */   
  $<vals>1->push_back($2);
  $$ = $<vals>1;
}
| expr
{
  $$ = new std::list<Value*>;
  $$->push_back($<val>1);
}
;         

expr: LPAREN MINUS token_or_expr_list RPAREN
{ 
/*
 *  This rule performs a unary minus in order to negate a single operand: either a token or expr. 
 */ 
  $$ = Builder.getInt32(0);

  if(($3->front()) == ($3->back())) {
    Value * tmp;
    tmp = $<vals>3->front();
    $$ = Builder.CreateNeg(tmp);
  } else {
    printf("Syntax error! Too many arguments in unary minus operation. ");
    YYABORT;
  }
  
}
| LPAREN PLUS token_or_expr_list RPAREN
{
/*
 *  This rule adds all the operands in a token or expr list together to produce a sum. 
 */ 
  $$ = Builder.getInt32(0);
  Value * sum = Builder.getInt32(0);
  Value * tmp = Builder.getInt32(0);
  std::list<Value*>::iterator it = $<vals>3->begin();
  
  for(it = $<vals>3->begin(); it != $<vals>3->end(); it++) {
    Value * tmp = *it;
    sum = Builder.CreateAdd(tmp,sum);
   }
  
  $$ = sum;
  
}
| LPAREN MULTIPLY token_or_expr_list RPAREN
{
/*
 *  This rule multiplies all the operands in a token or expr list together to produce a product. 
 */ 
  $$ = Builder.getInt32(0);
  Value * prod = Builder.getInt32(1);
  Value * tmp = Builder.getInt32(0);
  std::list<Value*>::iterator it = $<vals>3->begin();
  
  for(it = $<vals>3->begin(); it != $<vals>3->end(); it++) {
    Value * tmp = *it;
    prod = Builder.CreateMul(tmp,prod);
   }

   $$ = prod;  
}
| LPAREN DIVIDE token_or_expr_list RPAREN
{
/*
 *  This rule divides a list of signed integer operands in order from left to right to produce a quotient. 
 */ 
  $$ = Builder.getInt32(0);
  Value * quot = Builder.getInt32(1);
  Value * quotcheck = Builder.getInt32(1);  
  Value * tmp = Builder.getInt32(0);
  std::list<Value*>::iterator it = $<vals>3->begin();
  
  for(it = $<vals>3->begin(); it != $<vals>3->end(); it++) {
    Value * tmp = *it;
    Value * quotcheck = (*it)++;
    if(it!=($<vals>3->begin())) {
      tmp = quot;
      if(it==$<vals>3->end()) {
	quotcheck = Builder.getInt32(1);
      }
    }
    quot = Builder.CreateSDiv(quotcheck,tmp);
   }

   $$ = quot;
   
}
| LPAREN SETQ ID token_or_expr RPAREN
{
/*
 *  This rule stores either a token or expr into a variable specified by the ID. 
 */   
  Value* var = NULL;
  
  if (idLookup.find($3)==idLookup.end()){
    var = Builder.CreateAlloca(Builder.getInt32Ty(),nullptr,$3);
    idLookup[$3] = var;
  } else {
    var = idLookup[$3];
  }
  
  Builder.CreateStore($4,var);
  $$ = $4;
  
}
| LPAREN MIN token_or_expr_list RPAREN
{
/*
 *  This rule returns the smallest value in the token or expr list. 
 */
  Value * min = $<vals>3->front();
  Value * tmp = Builder.getInt32(0);
  std::list<Value*>::iterator it = $<vals>3->begin();
  
  for(it = $<vals>3->begin(); it != $<vals>3->end(); it++) {
    Value * tmp = *it;
    Value *icmp = Builder.CreateICmpULE(tmp,min);
	min = Builder.CreateSelect(icmp,tmp,min);
   }
  
  $$ = min;
  
}
| LPAREN MAX token_or_expr_list RPAREN
{
/*
 *  This rule returns the largest value in the token or expr list. 
 */ 
  Value * max = $<vals>3->front();
  Value * tmp = Builder.getInt32(0);
  std::list<Value*>::iterator it = $<vals>3->begin();
  
  for(it = $<vals>3->begin(); it != $<vals>3->end(); it++) {
    Value * tmp = *it;
    Value *icmp = Builder.CreateICmpUGE(tmp,max);
	max = Builder.CreateSelect(icmp,tmp,max);
   }
  
  $$ = max;
  
}
| LPAREN SETF token_or_expr token_or_expr RPAREN
{
  // ECE 566 only

}
| LPAREN AREF ID token_or_expr RPAREN
{
/*
 *  This rule returns a pointer to the nth element of an array specified by the token or expr . 
 */ 
  Value *tmp = Builder.getInt32(0);

  if(idLookup.find($3) != idLookup.end()) {
    tmp = Builder.CreateGEP(idLookup[$3],$4);
    $$ = Builder.CreateLoad(tmp);    
  } else {
    printf("Error: Array not found. ");
    $$ = Builder.getInt32(0);
  }
  
}
| LPAREN MAKEARRAY ID NUM token_or_expr RPAREN
{
  // ECE 566 only
 
}
;

token_or_expr_list:   token_or_expr_list token_or_expr
{
  // Add a token or expr onto an existing list.
  $<vals>1->push_back($2);
  $$ = $<vals>1;
}
| token_or_expr
{
  // When a single token or expr exists, create a new list for it.
  $$ = new std::list<Value*>;
  $$->push_back($1);
}
;

token_or_expr :  token
{
  // No type change.
  $$ = $1;
}
| expr
{
  // No type change.
  $$ = $1;
}
; 

token:   ID
{
  // Variable to be passed up as a token if created.
  if (idLookup.find($1) != idLookup.end())
    $$ = Builder.CreateLoad(idLookup[$1]);
  else
    {
      YYABORT;      
      }
}
| NUM
{
  // Integer to be passed up as a token.
  $$ = Builder.getInt32($1);
}
;

%%

void initialize()
{
  string s = "arg_array";
  idLookup[s] = (Value*)(Func->arg_begin()+1);

  string s2 = "arg_size";
  Argument *a = Func->arg_begin();
  Value * v = Builder.CreateAlloca(a->getType());
  Builder.CreateStore(a,v);
  idLookup[s2] = (Value*)v;
  
}

extern int line;

int yyerror(const char *msg)
{
  printf("%s at line %d.\n",msg,line);
  return 0;
}
