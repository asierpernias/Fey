# Fey
An tiny animated cat that lives on top of your dektop. Fey walks arround your taskbar, naps, sleeps, chases your cursor and eats the fish you drop for her.

## Features
- **Live on your desktop**: transparent, borderless always-on-top, click-through window. 
- **State machine**:: walking, idlinh, sleeping, chasing, eating and falling.
- **Drag and drop + gravity**:: pick Fey up, drag her arround and move it wherever you want that she will always return to your taskbar.
- **Sleep**:: falls asleep after a long period of inactivity, interact with her and she will wake up.
- **Chase**: every so often she decides to start following your cursor.
- **Fish**: spawn a fish by pressing "f" and Fey will run to eat it.
- **Sound**: a randomized meow (pitch and volume) when you click on here.
- **Dynamic ligh**: color and intesity that follows your computer´s clock.
- **Persistance**: remembers its position and starts the next session asleep.
- **Hover name tag**: hover to see her name.
- **PopUp menu**: right click for *Sleep*, *Mute* and *Exit*.

## Running

### Download
1. Download the lastest version from the releases page or [itchio](https://asierps.itch.io/fey)
2. Extract it anywhere.
3. Run `Fey.exe`. No installation is needed.

### From source
1. Install [Godot 4](https://godotengine.org).
2. Open the project and enable this in Project Settings:
    - `Display > Window > Per Pixel Transparency > Allowed`
    - `Display > Window > Size > Transparent`
    - `Display > Window > Stretch > Mode: disabled`
    - `Rendering > Viewport > Transparent Background`
3. Assingn `Fish Texture` and `Heart Texture` on the root node in the Inspect menu.
4. Turn off **Embed Game on Next Play**
5. Press Play

## Save Data

Here position is automatically stored in `user://pet.cfg`. Delete this file to reset it

## Screenshots
<img width="642" height="525" alt="Sin título" src="https://github.com/user-attachments/assets/7d91e7d6-5fd7-4cdc-93ae-d3b6321e5328" />
<img width="493" height="563" alt="Captura de pantalla 2026-10-11 010838" src="https://github.com/user-attachments/assets/ed5ea628-508e-421f-bf34-55e47ecaa309" />

## License 
This project is under the MIT License, open `LICENSE`to read more about it and more details.
