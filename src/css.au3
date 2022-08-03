#include-once
#include "../au3pm/DllStructEx.au3"
#include "../au3pm/Vector.au3"

#namespace \Css

$tagStylesheet = "IDispatch *rules;"
$tagRule = "IDispatch *selectors;IDispatch *declarations;"

Global Enum $SELECTOR_SIMPLE

$tagSimpleSelector = "PTR tag_name;PTR id;IDispatch *class;"
$tagDeclaration = "PTR name;Value value;"
Global Const $tagValue = "BYTE type;union{PTR keyword;union{FLOAT val;BYTE unit;} length;Color colorValue;} data;"

Global $VALUE_KEYWORD, $VALUE_LENGTH, $VALUE_COLORVALUE ; insert more values here
Global $UNIT_PX; insert more units here

Global Const $tagColor = _
    "BYTE r;"& _
    "BYTE g;"& _
    "BYTE b;"& _
    "BYTE a;"

#cs
# Parse one simple selector, e.g.: `type#id.class1.class2.class3`
# @return SimpleSelector
#ce
Func parse_simple_selector(ByRef $aCss)
    Local $selector = DllStructExCreate($tagSimpleSelector)
    $selector.class = Vector()
    While Not eof($aCss)
        Local $c = next_char($aCss)
        Switch $c
            Case '#'
            Case '.'
            Case '*'
            Case Else
                If valid_identifier_char($c) Then
                    $selector.tag_name = _WinAPI_CreateString(parse_identifier($aCss))
                Else
                    ExitLoop
                EndIf
        EndSwitch
    WEnd
    Return $selector
EndFunc

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
    Local $stylesheet = DllStructExCreate($tagStylesheet)
    $stylesheet.rules = parse_rules($parser)
    Return $stylesheet
EndFunc

Global Const $tagParser = "PTR pos;PTR input;"

#Region Parser
    #cs
    # Parse a rule set: `<selectors> { <declarations> }`.
    # @return Rule
    #ce
    Func parse_rule($self)
        Local $oRule = DllStructExCreate($tagRule)
        $oRule.selectors
        $oRule.declarations
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
            $c = next_char($self)
            Switch $c
                Case ','
                    consume_char($self)
                    consume_whitespace($self)
                Case '{'
                    ExitLoop
                Case Else
                    ConsoleWriteError(StringFormat("Unexpected character %s in selector list\n", $c))
                    Exit
            EndSwitch
        WEnd
        ; Return selectors with highest specificity first, for use in matching.
        ;~ selectors.sort_by(|a,b| b.specificity().cmp(&a.specificity()));  ;FIXME: implement
        Return $selectors
    EndFunc
#EndRegion Parser