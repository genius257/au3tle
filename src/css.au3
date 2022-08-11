#include-once
#include <AutoItConstants.au3>
#include "../au3pm/DllStructEx.au3"
#include "../au3pm/Vector.au3"

#namespace \Css

$tagStylesheet = "IDispatch *rules;"
$tagRule = "IDispatch *selectors;IDispatch *declarations;"

Global Enum $SELECTOR_SIMPLE

$tagSimpleSelector = "PTR tag_name;PTR id;IDispatch *class;"
$tagDeclaration = "PTR name;IDispatch *value;"
Global Const $tagValue = "BYTE type;union{PTR keyword;union{FLOAT val;BYTE unit;} length;Color colorValue;} data;"

Global $VALUE_KEYWORD, $VALUE_LENGTH, $VALUE_COLORVALUE ; insert more values here
Global $UNIT_PX; insert more units here

Global Const $tagColor = _
    "BYTE r;"& _
    "BYTE g;"& _
    "BYTE b;"& _
    "BYTE a;"

#Region Selector
    #cs
    # @typedef [Number, Number, Number] Specificity
    #ce

    #cs
    # @param DllStructEx<$tagSimpleSelector> $oSelf
    # @return Specificity
    #ce
    Func specificity($simple)
        ; http://www.w3.org/TR/selectors/#specificity
        Local $a = _WinAPI_GetString($simple.id)
        Local $b = $simple.class.Size()
        Local $c = _WinAPI_GetString($simple.tag_name)
        Local $aRet = [$a, $b, $c]
        Return $aRet
    EndFunc
#EndRegion Selector

#Region Value
    #cs
    # Return the size of a length in px, or zero for non-lengths.
    # @return FLOAT
    #ce
    Func to_px($self)
        Switch $self.type
            Case $VALUE_LENGTH
                If Not $self.data.length.unit = $UNIT_PX Then ContinueCase
                Return $self.data.length.val
            Case Else
                Return 0.0
        EndSwitch
    EndFunc
#EndRegion Value

#cs
# Parse a whole CSS stylesheet.
# @param String $source
# @return Stylesheet
#ce
Func parse($source)
    Local $parser = DllStructExCreate($tagParser)
    $parser.input = _WinAPI_CreateString($source)
    $parser.length = StringLen($source)
    Local $stylesheet = DllStructExCreate($tagStylesheet)
    $stylesheet.rules = parse_rules($parser)
    Return $stylesheet
EndFunc

Global Const $tagParser = "PTR pos;PTR input;PTR length;"

#Region Parser
    #cs
    # Parse a list of rule sets, separated by optional whitespace.
    # @return Vector<Rule>
    #ce
    Func parse_rules($self)
        Local $rules = Vector()
        While 1
            consume_whitespace($self)
            If eof($self) Then ExitLoop
            $rules.push_back(parse_rule($self))
        WEnd
        Return $rules
    EndFunc

    #cs
    # Parse a rule set: `<selectors> { <declarations> }`.
    # @return Rule
    #ce
    Func parse_rule($self)
        Local $oRule = DllStructExCreate($tagRule)
        $oRule.selectors = parse_selectors($self)
        $oRule.declarations = parse_declarations($self)
        Return $oRule
    EndFunc

    #cs
    # Parse a comma-separated list of selectors.
    # @return Vector<Selector>
    #ce
    Func parse_selectors($self)
        Local $selectors = Vector()
        While 1
            $selectors.push_back(parse_simple_selector($self))
            consume_whitespace($self)
            Local $c = next_char($self)
            Switch $c
                Case ','
                    consume_char($self)
                    consume_whitespace($self)
                Case '{'
                    ExitLoop
                Case Else
                    ConsoleWriteError(StringFormat("Unexpected character %s in selector list\n", AscW($c)))
                    Exit 1
            EndSwitch
        WEnd
        ; Return selectors with highest specificity first, for use in matching.
        ;~ selectors.sort_by(|a,b| b.specificity().cmp(&a.specificity()));  ;FIXME: implement
        Return $selectors
    EndFunc

    #cs
    # Parse one simple selector, e.g.: `type#id.class1.class2.class3`
    # @return SimpleSelector
    #ce
    Func parse_simple_selector($self)
        Local $selector = DllStructExCreate($tagSimpleSelector)
        $selector.class = Vector()
        While Not eof($self)
            Local $c = next_char($self)
            Switch $c
                Case '#'
                    consume_char($self)
                    $selector.id = _WinAPI_CreateString(parse_identifier($self))
                Case '.'
                    consume_char($self)
                    $selector.class.push_back(parse_identifier($self))
                Case '*'
                    ; universal selector
                    consume_char($self)
                Case Else
                    If valid_identifier_char($c) Then
                        $selector.tag_name = parse_identifier($self)
                    Else
                        ExitLoop
                    EndIf
            EndSwitch
        WEnd
        Return $selector
    EndFunc

    #cs
    # Parse a list of declarations enclosed in `{ ... }`.
    # @return Vector<Declaration>
    #ce
    Func parse_declarations($self)
        assert_eq(consume_char($self), '{')
        Local $declarations = Vector()
        While 1
            consume_whitespace($self)
            If next_char($self) = '}' Then
                consume_char($self)
                ExitLoop
            EndIf
            $declarations.push_back(parse_declaration($self))
        WEnd

        Return $declarations
    EndFunc

    #cs
    # Parse one `<property>: <value>;` declaration.
    # @return Declaration
    #ce
    Func parse_declaration($self)
        Local $property_name = parse_identifier($self)
        consume_whitespace($self)
        assert_eq(consume_char($self), ':')
        consume_whitespace($self)
        Local $value = parse_value($self)
        consume_whitespace($self)
        assert_eq(consume_char($self), ';')

        Local $declaration = DllStructExCreate($tagDeclaration)
        $declaration.name = $property_name
        $declaration.value = $value

        Return $declaration
    EndFunc

    ; Methods for parsing values:

    #cs
    # @return Value
    #ce
    Func parse_value($self)
        Switch next_char($self)
            Case '0', '1', '2', '3', '4', '5', '6', '7', '8', '9'
                Return parse_length($self)
            Case '#'
                Return parse_color($self)
            Case Else
                Local $value = DllStructExCreate($tagValue)
                $value.type = $VALUE_KEYWORD
                $value.data.keyword = parse_identifier($self)
                Return $value
        EndSwitch
    EndFunc

    #cs
    # @return Value
    #ce
    Func parse_length($self)
        Local $value = DllStructExCreate($tagValue)
        $value.type = $VALUE_LENGTH
        $value.data.length.val = parse_float($self)
        $value.data.length.unit = parse_unit($self)
        Return $value
    EndFunc

    #cs
    # @return float f32
    #ce
    Func parse_float($self)
        Local $s = consume_while($self, anonymous1659916092)
        Return Number($s, $NUMBER_DOUBLE)
    EndFunc

    Func anonymous1659916092($c)
        Return StringIsDigit($c)
    EndFunc

    #cs
    # @return Unit
    #ce
    Func parse_unit($self)
        Switch StringLower(parse_identifier($self))
            Case 'px'
                Return $UNIT_PX
            Case Else
                ConsoleWriteError('unrecognized unit')
                Exit 1
        EndSwitch
    EndFunc

    #cs
    # @return Value
    #ce
    Func parse_color($self)
        assert_eq(consume_char($self), '#')
        Local $value = DllStructExCreate($tagValue)
        $value.type = $VALUE_COLORVALUE
        Local $color = $value.data.colorValue
        $color.r = parse_hex_pair($self)
        $color.g = parse_hex_pair($self)
        $color.b = parse_hex_pair($self)
        $color.a = 255
        Return $value
    EndFunc

    #cs
    # Parse two hexadecimal digits.
    # @return BYTE u8
    #ce
    Func parse_hex_pair($self)
        Local $s = DllStructGetData(DllStructCreate("WCHAR[2]", $self.input + Number($self.pos, 2)*2), 1)
        $self.pos += 2
        Return Dec($s)
    EndFunc

    #cs
    # Parse a property name or keyword.
    # @return String
    #ce
    Func parse_identifier($self)
        return consume_while($self, valid_identifier_char)
    EndFunc

    #cs
    # Consume and discard zero or more whitespace characters.
    #ce
    Func consume_whitespace($self)
        consume_while($self, StringIsSpace)
    EndFunc

    #cs
    # Consume characters until `test` returns false.
    # @param Func(char) -> boolean  $test
    # @return String
    #ce
    Func consume_while($self, $test)
        Local $result = ""
        While (Not eof($self)) And $test(next_char($self))
            $result &= consume_char($self)
        WEnd
        Return $result
    EndFunc

    #cs
    # Return the current character, and advance self.pos to the next character.
    # @return char
    #ce
    Func consume_char($self)
        If $self.length = $self.pos Then Return Null
        Local $cur_char = DllStructGetData(DllStructCreate('WCHAR', $self.input + Number($self.pos, 2)*2), 1)
        $self.pos += 1
        Return $cur_char
    EndFunc

    #cs
    # Read the current character without consuming it.
    # @return char
    #ce
    Func next_char($self)
        If $self.length = $self.pos Then Return Null
        Return DllStructGetData(DllStructCreate('WCHAR', $self.input + Number($self.pos, 2)*2), 1)
    EndFunc

    #cs
    # Return true if all input is consumed.
    # @return boolean
    #ce
    Func eof($self)
        Return $self.pos >= $self.length
    EndFunc
#EndRegion Parser

#cs
# @param char $c
# @return boolean
#ce
Func valid_identifier_char($c)
    Return StringIsAlNum($c) Or $c = '-' Or $c = '_'
EndFunc

Func assert_eq($expected, $actual)
    If $expected = $actual Then Return
    ConsoleWriteError(StringFormat('Failed asserting that %s equals %s\n', $expected, $actual))
    Exit 1
EndFunc
