/* ================================================================================= */
/*  File Name: p1.lex                                                                */
/*                                                                                   */
/*  Description: This file implements the scanner for our programming language, P1.  */
/*                                                                                   */
/*  Emmanuel Rivera & Efren Martinez-Gomez                                           */
/*                                                                                   */
/*  Feb 19, 2020                                                                     */
/* ================================================================================= */

%{ 
/* P1. Implements scanner.  Some changes are needed! */

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

#include <list>

using namespace llvm;
  
int line=1;

#include "p1.y.hpp"
%}

%option nodefault 
%option yylineno
%option nounput
%option noinput
 
%% 

\n           line++;
[\t ]        ;

setq       { return SETQ;        }
min        { return MIN;         }
max        { return MAX;         }
aref       { return AREF;        }
setf       { return SETF;        }
make-array { return MAKEARRAY;   } 

[a-zA-Z_][a-zA-Z_0-9]*  { yylval.id = strdup(yytext); return ID; } 

[0-9]+  { yylval.num = atoi(yytext); return NUM; }        

"-"	    { return MINUS;       } 
"+"	    { return PLUS;        }  
"*"	    { return MULTIPLY;    }
"/"     { return DIVIDE;      }

"("     { return LPAREN;      }
")"     { return RPAREN;      }

.       { return ERROR;       }

%%
