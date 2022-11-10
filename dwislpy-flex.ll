%{

//
// dwislpy-flex.ll
//
// This is an implementation of a lexical analysis tool for the DWISLPY
// language. It is written using Flex as a series of token descriptions
// (given as regular expressions) along with a specification of the
// lexer engine called within the state machine that is triggered by
// ocurrences of token patterns. It compiles into the C++ source code
// dwislpy-flex.cc.
//
// The code relies on dwislpy-flex.hh which defines the class named
// DWISLPY::Lexer. This is the wrapper class for the lexer, and is a
// subclass of the FlexLexer class provided by the Flex tool.
//
// This lexer is used in combination with a parser written using Bison.
// The parser relies on repeated calls to the method `yylex`, with each
// call yielding a token code. The parser, for some token type, also
// has access to additional info within the Flex/Bison (1970s) interface
// of `yytext`, etc.
//
// This latter design makes some of the coding below a bit non-sensical
// so as to be compatible with the mostly-vanilla construction of a C++
// parser configured in Bison. As an example of the code awkwardness,
// the Lexer relies on a token type enumeration defined in a header
// file `dwislpy-bison.tab.hh` generated by Bison.
//
// ------
//
// What you'll find below is a few C/C++ globals necessary for Flex
// and Bison to work (I'm grateful to
//     https://github.com/jonathan-beard/simple_wc_example
// for providing a working example that I could draw from) and also
// a series of method definitions for the DWISLPY Lexer class.
//

    #include <string>
    #include "dwislpy-util.hh"
    #include "dwislpy-flex.hh"

    #include "dwislpy-bison.tab.hh"       // Defines DWISLPY::Parser::token
                                          // and DWISLPY::Parser::PLUS, etc.
    //
    using token = DWISLPY::Parser::token;                 // Useful aliases.
    using location_type = DWISLPY::Parser::location_type;

    // The method declared below is generated by Flex.
    //
    #undef  YY_DECL
    #define YY_DECL int DWISLPY::Lexer::yylex(DWISLPY::Parser::semantic_type* const lval, location_type* loc)

    //
    // Some configuration of Flex.
    //
    #define yyterminate() return token::Token_EOFL
    #define YY_NO_UNISTD_H

    //
    // What's executed at the start of every yylex call when a rule has
    // matched a sequence of characters in the source.
    //
    // #define YY_USER_ACTION advance_by_text(std::string{ yytext }, loc);

    // * * * * *
    // class DWISLPY::Lexer
    //
    // Provides a sequence of DWISLPY tokens to be parsed.
    //

    // lx.yylex(lvp,lp)
    //
    /* see YY_DECL */

    //
    // lx.advance_by_text(txt,l)
    //
    // In preparation for analyzing the next chunk of text and (maybe)
    // issuing a token, this code advances the lexer's administrative
    // state by scanning that next chunk of text. This is currently
    // just the text location, and the mark at the start of the text.
    //
    // This code is performed just before the "trigger" code in the
    // Flex matching rules gets executed, after the match rule has
    // been chosen. And so `yytext` contains that matched text and
    // is scanned by this method.
    //
    // The `l` parameter is a pointer to the Flex/Bison mechanism's
    // location information. This will be null when the lexer is run
    // standalone. If instead the lexer is run by Bison, it will not
    // be null, and the location will be updated also.
    //
    void DWISLPY::Lexer::advance_by_text(std::string txt, location_type* l) {
        l->step();
        for (char c: txt) {
            advance_by_char(c,l);
        }
    }

    // lx.advance_by_char(c,&l)
    //
    // Helper method for `advance_by_text` for handling a single character.
    //
    // The `l` parameter is a reference to the Flex/Bison mechanism's
    // location information. It is updated according to the character `c`.
    //
    void DWISLPY::Lexer::advance_by_char(char curr_char, location_type* l) {
        if (curr_char == '\n' ) {
            l->lines();
        } else if (curr_char == '\t') {
            int dc = (8 - (l->end.column - 1) % 8);
            l->columns(dc);
        } else if (curr_char != '\r') {
            l->columns(1);
        }
    }

    //
    // lx.indent_column(txt)
    //
    // Given a string `txt` made up of spaces and tabs that sit at the
    // start of a line of source code, figure out the column that they
    // tab to. For example:
    //
    //  * no spaces or tabs would tab to column 1
    //  * three spaces and no tabs would tab to column 4
    //  * a single tab character would tab to column 9
    //  * three spaces followed by a tab would also tab to column 9
    //
    // The method returns the column. It assumes that the string only
    // consists of tab and space characters.
    //
    int DWISLPY::Lexer::indent_column(std::string txt) {
        int spaces = 0;
        for (char c: txt) {
            if (c == '\t') {
                spaces += 8 - spaces % 8;
            } else if (c == ' ') {
                spaces++;
            }
        }
        return spaces + 1;
    }

    // debug_token
    //
    // Helper function that outputs a token to stdout.
    //
    void debug_token(int tkn_typ, std::string txt, location_type* l) {
        if (tkn_typ == token::Token_EOLN) {
            std::cout << "[NEWLINE]";
        } else if (tkn_typ == token::Token_EOFL) {
            std::cout << "[EOF]";
        } else if (tkn_typ == token::Token_INDT) {
            std::cout << "[INDENT]";
        } else if (tkn_typ == token::Token_DEDT) {
            std::cout << "[DEDENT]";
        } else if (tkn_typ == token::Token_STRG) {
            std::cout << "[STRING " << txt << "]";
        } else if (tkn_typ == token::Token_NMBR) {
            std::cout << "[NUMBER " << txt << "]";
        } else if (tkn_typ == token::Token_NAME) {
            std::cout << "[NAME '" << txt << "]";
        } else {
            std::cout << txt;
        }
        std::cout << ":" << l->begin.line << ":" << l->begin.column;
        std::cout << std::endl;
    }

    //
    // lx.issue(tkn,txt,l)
    //
    // This method returns the token type `tkn`, and it also advances
    // the current location `l` in the source code according to the text
    // of the string in `s`.
    //
    // This method is just a means for providing uniformity to most of
    // the scanner rules. This can be particularly useful when trying
    // to debug the scanner.
    //
    int DWISLPY::Lexer::issue(int tkn_typ, std::string txt,
                              location_type *l) {
        advance_by_text(txt,l);
        // debug_token(tkn_typ,txt,l);
        return tkn_typ;
    }

    //
    // lx.locate(l)
    //
    // Gives a `Locn` corresponding to the place in the text specified by l.
    // This is typically used for error reporting and for marking a program's
    // parsed constructs within the AST.
    //
    Locn DWISLPY::Lexer::locate(const location_type &l) {
        return Locn { src_name, l.begin.line, l.begin.column };
    }

    // lx.bail(m)
    //
    // Throws a DwislpyError exception with the message `m`.
    //
    void DWISLPY::Lexer::bail(DWISLPY::Parser::location_type* l,
                              std::string msg) {
        Locn locn { src_name, l->begin.line, l->begin.column };
        throw DwislpyError { locn, msg };
    }

%}

%state MID_LINE DEDENT

%option debug
%option nodefault
%option yyclass="DWISLPY::Lexer"
%option noyywrap
%option c++

INDT    \t|" "
EOLN    \r\n|\n\r|\n|\r
NMBR    (0|[1-9][0-9]*)
NAME    [_a-zA-Z][_a-zA-Z0-9]*
WSPC    {INDT}


%%

%{
    // Tie with Bison.
    // Code is executed at the beginning of yylex.
    yylval = lval;
%}


<INITIAL>{WSPC}*("#"[^\n\r]*)?{EOLN} {
    // Skip lines that only contain whitespace/comments.
    advance_by_text("\n", loc);
}

<INITIAL>{WSPC}+ {
    //
    // Handle some indentation at the start of a line..
    //
    std::string indent { yytext };
    advance_by_text(indent, loc);

    // Check this level versus the level on the stack.
    int level = indent_column(indent);
    int last_level  = indents.back();

    if (last_level == level) {
        // If the same, no INDENT/DEDENT.
        BEGIN(MID_LINE);

    } else if (last_level > level) {
        // If smaller, issue some DEDENTs.
        yyless(0);
        BEGIN(DEDENT);

    } else {
        // If bigger, issue an INDENT. Push onto the stack.
        indents.push_back(level);
        BEGIN(MID_LINE);
        return issue(token::Token_INDT,"",loc);

    }
}

<INITIAL>. {
    //
    // Handle the start of a line with no indentation/
    //
    unput(yytext[0]);
    int level = 1;
    int last_level  = indents.back();

    if (last_level > level) {
        //
        // Issue DEDENTs if we were indented to some level.
        //
        BEGIN(DEDENT);
    } else {
        BEGIN(MID_LINE);
    }
}

<DEDENT>{WSPC}+ {
    //
    // Issue DEDENTs and pop the stack until this level
    // matches the level at the top of the stack.
    //
    std::string indent { yytext };
    int level = indent_column(indent);
    int last_level  = indents.back();

    if (last_level < level) {
        //
        // Popping skipped the level we want. ERROR!
        //
        bail(loc, "Bad indentation.");

    } else if (last_level > level) {
        //
        // Issue a DEDENT and pop.
        //
        yyless(0);
        indents.pop_back();
        return issue(token::Token_DEDT,"",loc);

    } else {
        BEGIN(MID_LINE);
    }
}

<DEDENT>. {
    //
    // Issue DEDENTs and pop the stack until we are at
    // the leftmost level.
    //
    unput(yytext[0]);
    int level = 1;
    int last_level = indents.back();
    if (last_level < level) {
        //
        // This should never happen.
        //
        bail(loc, "Bad indentation.");

    } else if (last_level > level) {
        //
        // Issue a DEDENT and pop.
        //
        indents.pop_back();
        return issue(token::Token_DEDT,"",loc);
    } else {
        BEGIN(MID_LINE);
    }
}

<MID_LINE>("#"[^\n\r]*)?{EOLN} {
    // Handle ends of lines (maybe preceded by a comment).
    BEGIN(INITIAL);
    return issue(token::Token_EOLN,"\n",loc);
}

<MID_LINE>\"[^\"\n\r\t]*\" {
    // Handle string literals.
    std::string txt { yytext };
    int len = txt.length();
    std::string str = de_escape(txt.substr(1,len-2));
    yylval->build<std::string>(str);
    return issue(token::Token_STRG,txt,loc);
}

<MID_LINE>"=" {
    return issue(token::Token_ASGN,yytext,loc);
}

<MID_LINE>"+=" {
    return issue(token::Token_PLUSEQUAL,yytext,loc);
}

<MID_LINE>"-=" {
    return issue(token::Token_MINUSEQUAL,yytext,loc);
}

<MID_LINE>"and" {
    return issue(token::Token_LAND,yytext,loc);
}

<MID_LINE>"or" {
    return issue(token::Token_PLUSEQUAL,yytext,loc);
}

<MID_LINE>"<" {
    return issue(token::Token_LESS,yytext,loc);
}

<MID_LINE>"<=" {
    return issue(token::Token_LSQL,yytext,loc);
}

<MID_LINE>"==" {
    return issue(token::Token_EQUAL,yytext,loc);
}

<MID_LINE>"not" {
    return issue(token::Token_DONT,yytext,loc);
}

<MID_LINE>"if" {
    return issue(token::Token_DOIF,yytext,loc);
}

<MID_LINE>"while" {
    return issue(token::Token_DOWH,yytext,loc);
}

<MID_LINE>"(" {
    return issue(token::Token_LPAR,yytext,loc);
}

<MID_LINE>")" {
    return issue(token::Token_RPAR,yytext,loc);
}

<MID_LINE>"+" {
    return issue(token::Token_PLUS,yytext,loc);
}

<MID_LINE>"-" {
    return issue(token::Token_MNUS,yytext,loc);
}

<MID_LINE>"*" {
    return issue(token::Token_TMES,yytext,loc);
}

<MID_LINE>"//" {
    return issue(token::Token_IDIV,yytext,loc);
}

<MID_LINE>"%" {
    return issue(token::Token_IMOD,yytext,loc);
}

<MID_LINE>print {
    return issue(token::Token_PRNT,yytext,loc);
}

<MID_LINE>pass {
    return issue(token::Token_PASS,yytext,loc);
}

<MID_LINE>input {
    return issue(token::Token_INPT,yytext,loc);
}

<MID_LINE>int {
    return issue(token::Token_INTC,yytext,loc);
}

<MID_LINE>str {
    return issue(token::Token_STRC,yytext,loc);
}

<MID_LINE>True {
    return issue(token::Token_TRUE,yytext,loc);
}

<MID_LINE>False {
    return issue(token::Token_FALS,yytext,loc);
}

<MID_LINE>None {
    return issue(token::Token_NONE,yytext,loc);
}

<MID_LINE>{NAME} {
    // Handle identifier names.
    yylval->build<std::string>(yytext);
    return issue(token::Token_NAME, yytext, loc);
}

<MID_LINE>{NMBR} {
    // Handle integer literals.
    yylval->build<int>(std::stoi(yytext));
    return issue(token::Token_NMBR, yytext, loc);
}

<MID_LINE>{WSPC} {
    // Just skip this whitespace.
    advance_by_text(yytext,loc);
}

<MID_LINE><<EOF>> {
    return issue(token::Token_EOFL,"",loc);
}

<MID_LINE>. {
    bail(loc, "Unexpected character: " + std::string{yytext});
}

%%
