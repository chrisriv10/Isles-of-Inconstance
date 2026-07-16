class_name SoilData
extends RefCounted

var is_tilled: bool = false
var is_watered: bool = false
var is_composted: bool = false
var crop_id: String = ""
var days_grown: int = 0
## How many consecutive days a water-requiring crop has gone without water.
## Once this hits 2, the crop shows a wilted visual. At 3+, it stops growing.
var unwatered_days: int = 0
