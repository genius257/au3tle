#include "../au3pm/DllStructEx.au3"
#include "../au3pm/Vector.au3"

Global Const $tagRect2 = _
"FLOAT x;" & _
"FLOAT y;" & _
"FLOAT width;" & _
"FLOAT height;"

Global Const $tagDimensions = _
"Rect2 content;" & _  ; Position of the content area relative to the document origin:
"EdgeSizes padding;" & _ ; Surrounding edges:
"EdgeSizes border;" & _
"EdgeSizes margin;"

Global Const $tagEdgeSizes = _
"FLOAT left;" & _
"FLOAT right;" & _
"FLOAT top;" & _
"FLOAT bottom;"

Global Const $tagLayoutBox = _
"Dimensions dimensions;" & _
"BoxType box_type;" & _
"Vector children;"

Global Enum $BoxType_BlockNode, $BoxType_InlineNode, $BoxType_AnonymousBlock

Global Const $tagBoxType = _
"BYTE type;" & _
"IDispatch data;"

#Region LayoutBox
    #cs
    # @param BoxType $box_type
    # @return LayoutBox
    #ce
    Func new($box_type)
        $LayoutBox = DllStructExCreate($tagLayoutBox)
        $LayoutBox.box_type = $box_type
        $LayoutBox.dimensions = Null
        $LayoutBox.children = Vector()
    EndFunc

    #cs
    # @return StyledNode
    #ce
    Func get_style_node($self)
        Switch $self.box_type.type
            Case $BoxType_BlockNode, $BoxType_InlineNode
                Return $self.box_type.data
            Case $BoxType_AnonymousBlock
                ConsoleWriteError("Anonymous block box has no style node"&@CRLF)
                Exit 1
        EndSwitch
    EndFunc
#EndRegion LayoutBox

#cs
# Transform a style tree into a layout tree.
# @param StyledNode $node
# @param Dimensions $containing_block
# @return LayoutBox
#ce
Func layout_tree($node, $containing_block)
    ; The layout algorithm expects the container height to start at 0.
    ; TODO: Save the initial containing block height, for calculating percent heights.
    $containing_block.content.height = 0.0

    Local $root_box = build_layout_tree($node)
    $root_box.layout($containing_block)

    Return $root_box
EndFunc
