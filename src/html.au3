#include-once
#include <Memory.au3>
#include <WinAPIMem.au3>

Global Const $tagNode = _
    ""& _; // data common to all nodes:
    "Ptr children;"& _; children: Vec<Node>,
    ""& _; // data specific to each node type:
    "Int node_type;"& _; node_type: NodeType,
    "Ptr node_data;"

Enum _ ; enum NodeType
    $NodeType_Text, _ ; Text(String),
    $NodeType_Element ; Element(ElementData),

Global Const $tagElementData = _
    "Ptr tag_name;"& _; tag_name: String,
    "Ptr attributes;" ; attributes: AttrMap,

$tagAttrMap = _ ; type AttrMap = HashMap<String, String>;
    ""& _
    ""

Global Const $tagVec = _
    "Ptr front;"& _
    "Ptr back;"& _
    "Ptr items;"& _
    "Int size;"& _
    "Int ubound;"

#cs
# @param string $data
# @returns Node
#ce
Func text($data)
    Local $t = DllStructCreate($tagNode)
    $t.children = Vec()
    $t.node_type = $NodeType_Text
    $t.node_data = _WinAPI_CreateString($data)
    return $t
EndFunc

#cs
# @param string $name
# @param AttrMap $attrs
# @param Vec<Node> $children
# @returns Node
#ce
Func elem($name, $attrs, $children)
    Local $t = DllStructCreate($tagNode)
    $t.children = $children
    $t.node_type = $NodeType_Element
    $t.node_data = ElementData($name, $attrs)
    return $t
EndFunc

#cs
# @param string $tag_name
# @param AttrMap $attributes
# @returns ElementData
#ce
Func ElementData($tag_name, $attributes)
    Local $t = DllStructCreate($tagElementData)
    $t.tag_name = _WinAPI_CreateString($tag_name)
    $t.attributes = $attributes
EndFunc

Func Vec()
    Local $t = DllStructCreate($tagVec)
    $t.ubound = 100
    $t.items = MemCloneGlob(DllStructCreate("Ptr item[100];"))
    $t.size = 0
    Return DllStructCreate($tagVec, MemCloneGlob($t))
EndFunc

Func Vec_Add($vec, $item)
    $vec = IsDllStruct($vec) ? DllStructGetPtr($vec) : $vec
    $item = IsDllStruct($item) ? DllStructGetPtr($item) : $item
    Local $t = DllStructCreate($tagVec, $vec)
    If ($t.size >= $t.ubound) Then
        Vec_Resize($vec)
    EndIf
    $t.size += 1
    Local $items = DllStructCreate(StringFormat("Ptr item[%s];", $t.ubound), $t.items)
    DllStructSetData($items, $t.size, $item)
EndFunc

Func Vec_Resize($vec)
    $vec = IsDllStruct($vec) ? DllStructGetPtr($vec) : $vec
    Local $t = DllStructCreate($tagVec, $vec)
    Local $_items = DllStructCreate(StringFormat("Ptr item[%s];", $t.ubound), $t.items)
    $t.ubound += 100
    Local $items = DllStructCreate(StringFormat("Ptr item[%s];", $t.ubound))
    _MemMoveMemory(DllStructGetPtr($_items), DllStructGetPtr($items), DllStructGetSize($_items))
    _MemGlobalFree(GlobalHandle($t.items))
    $t.items = MemCloneGlob($items)
EndFunc

Func _Vec_FreeItems()
    ;TODO: implement
EndFunc

Func Vec_Free()
    ;TODO: implement
EndFunc

Func Vec_Get($vec, $index)
    $vec = IsDllStruct($vec) ? $vec : DllStructCreate($tagVec, $vec)
    If ($index > $vec.size) Then Return Null
    Local $items = DllStructCreate(StringFormat("Ptr item[%s];", $vec.ubound), $vec.items)
EndFunc

Func MemCloneGlob($tObject);clones DllStruct to Global memory and return pointer to new allocated memory
   Local $iSize = DllStructGetSize($tObject)
   Local $hData = _MemGlobalAlloc($iSize, $GMEM_MOVEABLE)
   Local $pData = _MemGlobalLock($hData)
   _MemMoveMemory(DllStructGetPtr($tObject), $pData, $iSize)
   Return $pData
EndFunc

Func GlobalHandle($pMem)
   Local $aRet = DllCall("Kernel32.dll", "ptr", "GlobalHandle", "ptr", $pMem)
   If @error<>0 Then Return SetError(@error, @extended, 0)
   If $aRet[0]=0 Then Return SetError(-1, @extended, 0)
   Return $aRet[0]
EndFunc
