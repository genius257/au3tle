
#include "dom.au3"
#include "../au3pm/AutoItObject_Internal.au3"
#include "../au3pm/Vector.au3"

#namespace \Parser

Global Enum $PARSER_POS, $PARSER_LENGTH, $PARSER_INPUT, $PARSER__END

Func parser($sInput)
    Local $aParser[$PARSER__END]
    $aParser[$PARSER_POS] = 0
    $aParser[$PARSER_INPUT] = StringToASCIIArray($sInput)
    $aParser[$PARSER_LENGTH] = StringLen($sInput)-1
    return $aParser
EndFunc

#cs
# Read the current character without consuming it.
# @return char
#ce
Func parser_next_char(ByRef $aParser)
    Return ChrW(($aParser[$PARSER_INPUT])[$aParser[$PARSER_POS]])
EndFunc

#cs
# Do the next characters start with the given string?
# @param string $s
# @return bool
#ce
Func parser_starts_with(ByRef $aParser, $s)
    Local $aS = StringToASCIIArray($s)
    Local $iS = StringLen($s) - 1
    For $i = 0 To $iS
        If ($aParser[$PARSER_INPUT])[$aParser[$PARSER_POS] + $i] <> $aS[$i] Then Return False
    Next
    Return True
EndFunc

#cs
# Return true if all input is consumed.
# @return bool
#ce
Func parser_eof(ByRef $aParser)
    Return $aParser[$PARSER_POS] > $aParser[$PARSER_LENGTH]
EndFunc

#cs
# Return the current character, and advance self.pos to the next character.
# @return char
#ce
Func parser_consume_char(ByRef $aParser)
    ;If parser_eof($aParser) Then return ChrW(0)
    Local $char = parser_next_char($aParser)
    $aParser[$PARSER_POS]+=1
    ;consolewrite($char)
    Return $char
EndFunc

#cs
# Consume characters until `test` returns false.
# @param callable($char):bool $test
# @return string
#ce
Func parser_consume_while(ByRef $aParser, $test)
    Local $result = ""
    While Not parser_eof($aParser) And $test(parser_next_char($aParser))
        $result &= parser_consume_char($aParser)
    WEnd
    Return $result
EndFunc

#cs
# Consume and discard zero or more whitespace characters.
#ce
Func parser_consume_whitespace(ByRef $aParser)
    Return parser_consume_while($aParser, StringIsSpace)
EndFunc

#cs
# Parse a tag or attribute name.
# @return string
#ce
Func parser_parse_tag_name(ByRef $aParser)
    Return parser_consume_while($aParser, StringIsAlNum)
EndFunc

#cs
# Parse a single node.
# @return \Dom\Node
#ce
Func parser_parse_node(ByRef $aParser)
    Switch parser_next_char($aParser)
        Case '<'
            Return parser_parse_element($aParser)
        Case Else
            Return parser_parse_text($aParser)
    EndSwitch
EndFunc

#cs
# Parse a text node.
# @return \Dom\Node
#ce
Func parser_parse_text(ByRef $aParser)
    Return text(parser_consume_while($aParser, anonymous1658152124))
EndFunc

#cs
# @internal
#ce
Func anonymous1658152124($char)
    Return Not ($char = '<')
EndFunc

#cs
# Parse a single element, including its open tag, contents, and closing tag.
# @return \Dom\Node
#ce
Func parser_parse_element(ByRef $aParser)
    ; Opening tag.
    assert(parser_consume_char($aParser) = '<')
    Local $tag_name = parser_parse_tag_name($aParser)
    Local $attrs = parser_parse_attributes($aParser)
    assert(parser_consume_char($aParser) = '>')

    ; Contents.
    Local $children = parser_parse_nodes($aParser)

    ; Closing tag.
    assert(parser_consume_char($aParser) = '<')
    assert(parser_consume_char($aParser) = '/')
    assert(parser_parse_tag_name($aParser) = $tag_name)
    assert(parser_consume_char($aParser) = '>')

    Return elem($tag_name, $attrs, $children)
EndFunc

#cs
# Parse a single name="value" pair.
# @return [string, string]
#ce
Func parser_parse_attr(Byref $aParser)
    Local $name = parser_parse_tag_name($aParser)
    assert(parser_consume_char($aParser) = '=')
    Local $value = parser_parse_attr_value($aParser)
    Local $return = [$name, $value]
    return $return
EndFunc

#cs
# Parse a quoted value.
# @returns string
#ce
Func parser_parse_attr_value(Byref $aParser)
    Local $open_quote = parser_consume_char($aParser)
    assert($open_quote = '"' Or $open_quote = "'")
    anonymous1658211806(Null, $open_quote); Setup fake lambda expression scope
    Local $value = parser_consume_while($aParser, anonymous1658211806)
    assert(parser_consume_char($aParser) = $open_quote)
    Return $value
EndFunc

Func anonymous1658211806($c, $x = Null)
    Local Static $open_quote = Null
    If @NumParams = 2 then $open_quote = $x
    Return Not ($c = $open_quote)
EndFunc

#cs
# Parse a list of name="value" pairs, separated by whitespace.
# @return \Dom\AttrMap
#ce
Func parser_parse_attributes(Byref $aParser)
    Local $attributes = IDispatch()
    While 1
        parser_consume_whitespace($aParser)
        If parser_next_char($aParser) = '>' Then ExitLoop
        Local $result = parser_parse_attr($aParser)
        Local $name = $result[0]
        Local $value = $result[1]
        $attributes.__set($name, $value)
    WEnd
    Return $attributes
EndFunc

#cs
# Parse a sequence of sibling nodes.
# @return Vec<\Dom\Node>
#ce
Func parser_parse_nodes(Byref $aParser)
    $nodes = Vector()
    While 1
        parser_consume_whitespace($aParser)
        If parser_eof($aParser) Or parser_starts_with($aParser, '</') Then ExitLoop
        $nodes.push_back(parser_parse_node($aParser))
    WEnd
    Return $nodes
EndFunc

#cs
# Parse an HTML document and return the root element.
# @param string $source
# @return \Dom\Node
#ce
Func parser_parse($source)
    Local $nodes = parser_parse_nodes(parser($source))

    ; If the document contains a root element, just return it. Otherwise, create one.
    If $nodes.Size = 1 then
        Return $nodes.at(0)
    endif
    Return elem("html", IDispatch(), $nodes)
EndFunc

Func assert($condition, $line = @ScriptLineNumber)
    If $condition Then Return
    ConsoleWrite("Assertion failed on line "&$line&@CRLF)
    Exit
EndFunc
