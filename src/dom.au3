#include-once
#include "../au3pm/DllStructEx.au3"
#include "../au3pm/Vector.au3"
#include <Array.au3>

#namespace \Dom

;$tagNode = "Vector *children;NodeType node_type;"
;$tagNodeType = "BYTE num;"
;$tagNode = "Vector *children;NodeType node_type;"
$tagNode = "IDispatch *children;NodeType node_type;"
;$tagNodeType = "BYTE type;union{PTR text;IDispatch *element;} data;"
$tagNodeType = "BYTE type;union{PTR text;PTR element;} data;"

Global Enum _
$NodeType_NONE, _
$NodeType_TEXT, _ ;String
$NodeType_ELEMENT ;ElementData

;$tagElementData = "String *tag_name;AttrMap *attributes;"
; type AttrMap = HashMap<String, String>;
;$tagElementData = "String *tag_name;IDispatch *attributes;"
;$tagString = "WCHAR[255] name;"
$tagElementData = "PTR tag_name;IDispatch *attributes;"

Func Node()
    $oNode = DllStructExCreate($tagNode)
    If @error <> 0 then Return SetError(1, 0, 0)
    Return $oNode
EndFunc

Func ElementData()
    $oElementData = DllStructExCreate($tagElementData)
    If @error <> 0 then Return SetError(1, 0, 0)
    Return $oElementData
EndFunc

#cs
# @param string $data
# @return Node
#ce
Func text($data)
    $oNode = Node()
    If @error <> 0 then Return SetError(1, 0, 0)
    $oNode.children = Vector()
    $oNode.node_type.type = $NodeType_TEXT
    $oNode.node_type.data.text = _WinAPI_CreateString($data)
    Return $oNode
EndFunc

#cs
# @param string $name
# @param AttrMap $attrs
# @param Vec<Node> $children
# @return Node
#ce
Func elem($name, $attrs, $children)
    $oNode = Node()
    If @error <> 0 then Return SetError(1, 0, 0)
    $oNode.children = $children
    $oNode.node_type.type = $NodeType_ELEMENT
    $oElementData = ElementData()
    If @error <> 0 then Return SetError(1, 0, 0)
    ;$pString = IsString($name) ? _WinAPI_CreateString($name) : $name
    ;consolewrite("pString: "&$pString&@crlf)
    ;$oElementData.tag_name = $pString
    $oElementData.tag_name = IsString($name) ? _WinAPI_CreateString($name) : $name
    $oElementData.attributes = $attrs
    ;$oNode.node_type.data.element = $oElementData
    __DllStructEx_AddRef(Ptr($oElementData))
    $oNode.node_type.data.element = Ptr($oElementData)
    Return $oNode
EndFunc

;$t = DllStructExCreate($tagNode)
;If @error <> 0 Then Exit
;ConsoleWrite(DllStructExGetStructString($t)&@CRLF)
;ConsoleWrite(DllStructExGetTranspiledStructString($t)&@CRLF)

Func Node_toString($node)
    $sHTML = ""
    ;consolewrite("["&VarGetType($node)&"]: "&$node&@crlf)
    $node = IsObj($node) ? $node : DllStructExCreate($tagNode, ptr($node))
    Local $node_type = $node.node_type
    Switch $node_type.type
        Case $NodeType_TEXT
            ;$sHTML &= _WinAPI_GetString($node_type.data)
            $sHTML &= _WinAPI_GetString($node.node_type.data.text)
        Case $NodeType_ELEMENT
            ;consolewrite("["&VarGetType($node_type.data)&"]: "&$node_type.data&@crlf)
            Local $oElementData = ObjCreateInterface($node_type.data.element, $__g_DllStructEx_IID_IDispatch, Default, True)
            ;Local $oElementData = DllStructExCreate($tagElementData, Ptr($node_type.data))
            ;consolewrite(StringFormat("tag name ptr: 0x%08X\n", $oElementData.tag_name))
            Local $tag_name = _WinAPI_GetString(Ptr($oElementData.tag_name))
            ;consolewrite(StringFormat("tag name: %s\n", $tag_name))
            ;consolewrite($oElementData.tag_name&@crlf)
            ;consolewrite($tag_name&@crlf)
            $aKeys = $oElementData.attributes.__keys()
            ;consolewrite(_ArrayToString($aKeys, )&@crlf)
            $sHTML &= '<' & $tag_name
            For $sKey In $oElementData.attributes.__keys()
                $sHTML &= " "&$sKey&'="'&$oElementData.attributes.__get($sKey)&'"'
            Next
            $sHTML &= '>'
            Local $children = $node.children
            ;consolewrite("vector_len: "&vector_len($children)&@crlf)
            For $i = 0 To $children.Size - 1
                ;$sHTML &= Node_toString(vector_get($children, $i))
                $sHTML &= Node_toString($children.at($i))
            Next
            $sHTML &= '</' & $tag_name & '>'
        Case Else
            return SetError(1, @ScriptLineNumber, $sHTML)
    EndSwitch
    Return $sHTML
EndFunc

; Element methods
#Region ElementData
    #cs
    # @return string?
    #ce
    Func id($self)
        Return $self.attributes.__get("id")
    EndFunc

    #cs
    # @return Array<string>
    #ce
    Func classes($self)
        Local $classlist = $self.attributes.__get("class")
        If IsString($classlist) Then Return StringSplit($classlist, " ")
        Local $emptyArray[0]
        Return $emptyArray
    EndFunc
#EndRegion ElementData
