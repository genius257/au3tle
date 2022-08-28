#include-once
#include "../au3pm/AutoItObject_Internal.au3"
#include "../au3pm/DllStructEx.au3"
#include "../au3pm/Vector.au3"
#include "css.au3"
#include "dom.au3"

; Map from CSS property names to values.
$typePropertyMap = "IDispatch"; HashMap<String, Value>

; A node with associated style data.
$tagStyledNode = _
    "IDispatch *node;"& _ ; pointer to a DOM node
    "PropertyMap *specified_values;"& _
    "IDispatch *children;" ; Vec<StyledNode<'a>>

Global Enum $DISPLAY_INLINE, $DISPLAY_BLOCK, $DISPLAY_NONE

#Region StyledNode
    #cs
    # Return the specified value of a property if it exists, otherwise `None`.
    # @param string $name
    # @return Value?
    #ce
    Func value($self, $name)
        Return $self.specified_values.__get($name)
    EndFunc

    #cs
    # Return the specified value of property `name`, or property `fallback_name` if that doesn't
    # exist, or value `default` if neither does.
    # @param string $name
    # @param string $fallback_name
    # @param Value $default
    # @return Value
    #ce
    Func lookup($self, $name, $fallback_name, $default)
        Local $result = value($self, $name)
        $result = $result = Null ? value($self, $fallback_name) : $result
        $result = $result = Null ? $default : $result
        Return $result
    EndFunc

    #cs
    # The value of the `display` property (defaults to inline).
    # @return Display
    #ce
    Func display($self)
        Local $value = value($self, "display")
        Switch $value = null ? $value : $value.type
            Case $VALUE_KEYWORD
                Local $keyword = _WinAPI_GetString($value.data.keyword)
                Switch $keyword
                    Case "block"
                        Return $DISPLAY_BLOCK
                    Case "none"
                        Return $DISPLAY_NONE
                    Case Else
                        Return $DISPLAY_INLINE
                EndSwitch
            Case Else
                Return $DISPLAY_INLINE
        EndSwitch
    EndFunc
#EndRegion StyledNode

#cs
# Apply a stylesheet to an entire DOM tree, returning a StyledNode tree.
#
# This finds only the specified values at the moment. Eventually it should be extended to find the
# computed values too, including inherited values.
# @param Node $root
# @param Stylesheet $stylesheet
# @return StyledNode
#ce
Func style_tree($root, $stylesheet)
    Local $StyledNode = DllStructExCreate($tagStyledNode)
    $StyledNode.node = $root
    Switch $root.node_type
        Case $NodeType_ELEMENT
            $StyledNode.specified_values = specified_values()
        Case $NodeType_TEXT
            $StyledNode.specified_values = IDispatch()
    EndSwitch

    $processedChildren = Vector()
    $rootChildren = $root.children
    For $i = 0 To $rootChildren.Size - 1
        $processedChildren.push_back(style_tree($rootChildren.at($i), $stylesheet))
    Next
    $StyledNode.children = $processedChildren

    Return $StyledNode
EndFunc

#cs
# Apply styles to a single element, returning the specified styles.
#
# To do: Allow multiple UA/author/user stylesheets, and implement the cascade.
# @param ElementData $elem
# @param Stylesheet $stylesheet
# @return PropertyMap
#ce
Func specified_values($elem, $stylesheet)
    Local $values = IDispatch()
    Local $rules = matching_rules($elem, $stylesheet)

    ; Go through the rules from lowest to highest specificity.
    ;FIXME: sort rules: rules.sort_by(|&(a, _), &(b, _)| a.cmp(&b));
    For $i = 0 To $rules.Size - 1
        Local $rule = $rules.at($i)
        Local $declarations = $rule.declarations
        For $j = 0 To $declarations.Size - 1
            Local $declaration = $declarations.at($j)
            $values.__set($declaration.name, $declaration.value)
        Next
    Next

    Return $values
EndFunc

;Global Const $typeMatchedRule = (Specificity, Rule)

#cs 
# Find all CSS rules that match the given element.
# @param ElementData $elem
# @param Stylesheet $stylesheet
# @return Vector<MatchedRule>
#ce
Func matching_rules($elem, $stylesheet)
    ; For now, we just do a linear scan of all the rules.  For large
    ; documents, it would be more efficient to store the rules in hash tables
    ; based on tag name, id, class, etc.
    ; FIXME: stylesheet.rules.iter().filter_map(|rule| match_rule(elem, rule)).collect()
    Local $rules = $stylesheet.rules
    Local $result = Vector()
    For $i = 0 To $rules.Size - 1
        Local $rule = $rules.at($i)
        if match_rule($elem, $rule) Then $result.push_back($rule)
    Next
    Return $result
EndFunc

#cs
# If `rule` matches `elem`, return a `MatchedRule`. Otherwise return `None`.
# @param ElementData $elem
# @param Rule
# @return MatchedRule?
#ce
Func match_rule($elem, $rule)
    ; Find the first (most specific) matching selector.
    #cs
    rule.selectors.iter().find(|selector| matches(elem, *selector))
        .map(|selector| (selector.specificity(), rule))
    #ce
    Local $selectors = $rule.selectors;
    Local $keys = $selectors.__keys()
    For $i = 0 To UBound($keys, 1) - 1

        Local $selector = $selectors.at($keys[$i])
        If matches($elem, $selector) Then
            Local $aReturn = [specificity($selector), $rule]
            Return $aReturn
        EndIf
    Next
    Return Null
EndFunc

#cs
# Selector matching:
# @param ElementData $elem
# @param Selector $selector
# @return boolean
#ce
Func matches($elem, $selector)
    #cs
    ; TODO: Currently only selector type available is simple. and no way of checking. Until changed this code is commented.
    Switch $selector.type
        Case "Simple"
            matches_simple_selector($elem, $selector)
    EndSwitch
    #ce
    Return matches_simple_selector($elem, $selector)
EndFunc

#cs
# @param ElementData $elem
# @param SimpleSelector $selector
# @return boolean
#ce
Func matches_simple_selector($elem, $selector)
    ; Check type selector
    If Not ($elem.tag_name == _WinAPI_GetString($selector.tag_name)) Then Return False

    ; Check ID selector
    If Not ($elem.id == _WinAPI_CreateString($selector.id)) Then Return False

    ; Check class selectors
    Local $elem_classes = classes($elem)
    Local $selector_class = $selector.class
    For $i = 0 To $selector_class.size - 1
        For $j = 0 To UBound($elem_classes)
            If $selector.at($i) = $elem_classes[$j] Then ContinueLoop;TODO: verify if case sensitive matching is required.
            Return False
        Next
    Next

    ; We didn't find any non-matching selector components.
    Return True
EndFunc
