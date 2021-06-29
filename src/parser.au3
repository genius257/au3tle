#include-once
#include "html.au3"

$tagParser = _
    "uint pos;"& _ ; pos: usize, // "usize" is an unsigned integer, similar to "size_t" in C
    "ptr input;"   ; input: String,

; Read the current character without consuming it.
Func Parser_next_char($parser)
    Return DllStructGetData(DllStructCreate("WCHAR", $parser.input + $parser.pos * 2), 1)
EndFunc

; Do the next characters start with the given string?
Func Parser_starts_with($parser, $s)
    Return DllStructGetData(DllStructCreate(StringFormat("WCHAR[%s]", StringLen($s)), $parser.input + $parser.pos * 2), 1) == $s
EndFunc

; Return true if all input is consumed.
Func Parser_eof($parser)
    Return $parser.pos >= _WinAPI_StrLen($parser.input)
EndFunc

; Return the current character, and advance self.pos to the next character.
Func Parser_consume_char($parser)
    Local $char = Parser_next_char($parser)
    $parser.pos += 1
    Return $char
EndFunc

; Consume characters until `test` returns false.
Func Parser_consume_while($parser, $test)
    Local $result = ""
    While (Not Parser_eof($parser)) And Call($test, Parser_next_char($parser))
        $result &= Parser_consume_char($parser)
    WEnd
    Return $result
EndFunc

; Consume and discard zero or more whitespace characters.
Func Parser_consume_whitespace($parser)
    Parser_consume_while($parser, StringIsSpace)
EndFunc

; Parse a tag or attribute name.
Func Parser_parse_tag_name($parser)
    ;
EndFunc
