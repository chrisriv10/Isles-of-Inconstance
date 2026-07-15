extends Resource
class_name ItemData

## Static definition of an inventory item. Create .tres instances of this
## resource for each item and register them with DataManager.

@export var id: String = ""
@export var display_name: String = ""
@export var icon: Texture2D
@export var stack_size: int = 99
@export var sell_price: int = 0
@export_multiline var description: String = ""
