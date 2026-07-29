# UI Polish Add-ons for Godot 4

Drop-in scripts to instantly polish your game's UI with animations, sounds, and notifications. No manual editor work required!

## 📦 What's Included

### 1. UITweenHelper.gd
**Smooth panel open/close animations**

Add slide + fade effects to any UI panel with one line of code.

**Usage:**
```gdscript
# In your UI script (Shop.gd, InventoryUI.gd, etc.)

func open() -> void:
    is_open = true
    dim.visible = true
    panel.visible = true
    
    # Add this one line:
    UITweenHelper.animate_open(panel, 0.25, 20.0)
    
    refresh()

func close() -> void:
    is_open = false
    
    # Add this one line:
    UITweenHelper.animate_close(panel, 0.2, 20.0, func(): 
        dim.visible = false
        panel.visible = false
    )
```

**Features:**
- ✅ Slide + fade in/out
- ✅ Configurable duration and offset
- ✅ Auto sound effects (uses AudioManager)
- ✅ Pulse and shake effects available

---

### 2. ToastNotification.gd
**Popup notifications for achievements, errors, hints**

Show temporary messages that auto-fade with icons and colors.

**Usage:**
```gdscript
# From anywhere in your code:

# Simple notification
ToastNotification.show_toast("Crop harvested!")

# With type (changes color and icon)
ToastNotification.show_toast("Rare mutation discovered!", ToastNotification.ToastType.SUCCESS)
ToastNotification.show_toast("Not enough money!", ToastNotification.ToastType.ERROR)
ToastNotification.show_toast("Day 5 starting...", ToastNotification.ToastType.INFO, 3.0)
```

**Types:**
- `INFO` - Blue ℹ (default)
- `SUCCESS` - Green ✓
- `WARNING` - Orange ⚠
- `ERROR` - Red ✕

**Features:**
- ✅ Queue system (handles multiple toasts)
- ✅ Auto fade in/out
- ✅ Color-coded by type
- ✅ Unicode icons included

---

### 3. ButtonSound.gd
**Automatic hover/click sounds for buttons**

Add satisfying audio feedback to all your buttons.

**Usage Option 1 - As child node:**
1. Select any Button node in your scene
2. Add Child Node → Node
3. Attach script: `ButtonSound.gd`
4. Done! ✅

**Usage Option 2 - Via code:**
```gdscript
# In _ready() of your UI scene:
for btn in get_tree().get_nodes_in_group("shop_buttons"):
    ButtonSound.add_to_button(btn, true, true, -5.0)
```

**Features:**
- ✅ Hover and click sounds
- ✅ Uses AudioManager (or procedural fallback)
- ✅ Random pitch variation for variety
- ✅ Configurable volume

---

## 🚀 Quick Integration Examples

### Example 1: Polish Your Shop UI

Edit `scripts/ui/Shop.gd`:

```gdscript
func open() -> void:
    is_open = true
    dim.visible = true
    panel.visible = true
    
    # REPLACE the simple visible = true with:
    UITweenHelper.animate_open(panel, 0.25, 20.0)
    
    refresh()

func close() -> void:
    is_open = false
    
    # REPLACE with animated close:
    UITweenHelper.animate_close(panel, 0.2, 20.0, func(): 
        dim.visible = false
        panel.visible = false
    )

# Add button sounds to all shop buttons
func _refresh_seeds() -> void:
    _clear(seeds_list)
    # ... existing code ...
    var select_button := Button.new()
    select_button.text = "Buy"
    select_button.pressed.connect(func(): _buy_seed(seed_item))
    
    # ADD THIS LINE:
    ButtonSound.add_to_button(select_button)
    
    row.add_child(select_button)
```

### Example 2: Show Toast on Purchase

In `Shop.gd`, update `_buy_seed()`:

```gdscript
func _buy_seed(seed_item: ItemData) -> void:
    if GameManager.spend_money(seed_item.buy_price):
        InventoryManager.add_item(seed_item.id, 1)
        
        # ADD THIS LINE:
        ToastNotification.show_toast("Bought %s!" % seed_item.display_name, ToastNotification.ToastType.SUCCESS)
        
        refresh()
```

### Example 3: Error Toast for Insufficient Funds

In `Shop.gd`, update purchase functions:

```gdscript
func _buy_seed(seed_item: ItemData) -> void:
    if not GameManager.spend_money(seed_item.buy_price):
        # ADD ERROR FEEDBACK:
        ToastNotification.show_toast("Not enough coins!", ToastNotification.ToastType.ERROR)
        return
    
    InventoryManager.add_item(seed_item.id, 1)
    ToastNotification.show_toast("Purchased %s!" % seed_item.display_name, ToastNotification.ToastType.SUCCESS)
    refresh()
```

### Example 4: Mutation Celebration

Your `HUD.gd` already shows mutations! Enhance it:

```gdscript
func _on_crop_mutated(old_name: String, new_name: String, mutation_name: String) -> void:
    mutation_label.text = "✨ %s mutated into %s! (%s)" % [old_name, new_name, mutation_name]
    mutation_label.visible = true
    mutation_label_panel.visible = true
    mutation_toast_timer.start()
    
    # ADD TOAST:
    ToastNotification.show_toast("%s → %s!" % [old_name, new_name], ToastNotification.ToastType.SUCCESS, 4.0)
    
    # ADD SOUND:
    if Engine.has_singleton("AudioManager"):
        var audio = Engine.get_singleton("AudioManager")
        audio.play(5) # MUTATION sound
```

---

## 🎨 Customization

All scripts have `@export` variables you can tweak in the Inspector:

**UITweenHelper:**
- `open_duration` - How long opening animation takes
- `slide_offset` - How far panel slides (pixels)
- `use_slide` / `use_fade` - Enable/disable effects

**ToastNotification:**
- `default_duration` - How long toasts stay visible
- `fade_duration` - Fade in/out speed
- `max_queue_size` - Max simultaneous toasts

**ButtonSound:**
- `play_on_hover` / `play_on_click` - When to play
- `volume_db` - Sound volume
- `pitch_variation` - Randomness for variety

---

## 📁 File Structure

```
res://scripts/ui/
├── UITweenHelper.gd      # Panel animations
├── ToastNotification.gd  # Popup notifications  
├── ButtonSound.gd        # Button audio feedback
└── UI_POLISH_README.md   # This file
```

---

## 🔧 Troubleshooting

**Animations not working?**
- Make sure the Control node is visible before calling `animate_open()`
- Check that parent CanvasLayer allows input

**Sounds not playing?**
- AudioManager autoload must be enabled (it is in your project)
- Check Audio Bus volume isn't muted

**Toasts not appearing?**
- Ensure there's a CanvasLayer or Control parent
- Try calling from `_ready()` or after scene loads

---

## 💡 Pro Tips

1. **Combine effects**: Use toast + sound + animation together for maximum impact
2. **Consistent timing**: Use same durations across UI for cohesive feel (0.2-0.3s works well)
3. **Sound variety**: ButtonSound's pitch variation prevents repetitive audio
4. **Toast queue**: Multiple toasts automatically queue up - great for combo actions

---

## ✨ Before & After

**Before:**
- Panels pop instantly (jarring)
- Buttons are silent (no feedback)
- Events go unnoticed (no celebration)

**After:**
- Panels slide & fade smoothly ✨
- Buttons click satisfyingly 🔊
- Achievements pop with fanfare 🎉

**Total effort:** Copy 4 files, add 1-2 lines per feature!

Enjoy your polished UI! 🎮
