# DM7 Link — User Guide

DM7 Link is show control for the **Yamaha DM7**, running on a Mac or Windows computer at FOH.
It connects to the console over the network and adds three things the desk does not do on its own:

| Feature | What it does |
|---|---|
| **Waves SuperRack** | The desk drives SuperRack. SEL opens the rack that channel feeds, a scene recall recalls a snapshot, a scene store stores one, and the desk's tempo sets SuperRack's tempo. |
| **Timecode** | LTC on an audio interface input fires cues that recall desk scenes or run macros, exactly when the show plays through them. |
| **Macros** | Short programs, built from blocks, that act on the desk: set, change or fade any parameter, recall or store scenes, react to levels, values, times or timecode. |

Each feature can be switched off in **Settings**. A feature that is off stops completely and is
hidden from the window.

---

## Contents

1. [Getting started](#1-getting-started)
2. [The window](#2-the-window)
3. [Console](#3-console)
4. [Show files](#4-show-files)
5. [Waves SuperRack](#5-waves-superrack)
6. [Timecode](#6-timecode)
7. [Macros](#7-macros)
8. [Settings](#8-settings)
9. [Files and backups](#9-files-and-backups)
10. [Troubleshooting](#10-troubleshooting)
11. [What DM7 Link does not do](#11-what-dm7-link-does-not-do)

---

## 1. Getting started

### What you need

- A Yamaha DM7 on the same network as the computer.
- macOS or Windows. Linux works as well.
- For Waves: SuperRack (Performer or SoundGrid) with its ProLink controller, and a **wired**
  network adapter on the SuperRack computer.
- For timecode: any audio interface with a free line input.

### Install and start

The packaged app (`DM7 Link.app` / `DM7 Link.exe`) needs nothing else. From source:

```bash
pip install -r requirements.txt
python3 run.py                 # connects to the console used last time
python3 run.py 192.168.0.2     # ...or to this address
```

On the first start DM7 Link opens on **Console** and searches the network for a DM7.

---

## 2. The window

### The rail (left)

The places of the app, each with a lamp:

| Lamp | Meaning |
|---|---|
| Green | Working: connected, locked, link up |
| Amber, pulsing | Waiting: connecting, waiting for SuperRack, no timecode yet |
| Amber, steady | Armed or freewheeling |
| Red | A fault: the console is not answering, the audio input will not open |
| Hollow | Off or idle |

**Settings** sits at the foot of the rail.

### The show bar (top)

Always visible, read left to right like a signal path:

**Console** › **Scene** › **Selected** channel and the rack it opens › **SuperRack** snapshot and
tempo › **Timecode**.

- **Show mode** (pill on the right) locks SuperRack to show use. See [Show mode](#show-mode).
- Click the timecode to go to the Timecode page.
- A part whose feature is switched off is left out of the bar.

---

## 3. Console

**Consoles on the network** lists every DM7 that answered the search. Click **Connect** next to one.
**Rescan** searches again.

**Console address** connects to an address typed by hand. **Recent** lists the addresses used before.

After a connect, DM7 Link reads the console (a few seconds) and is then online. If the link
drops, it reconnects by itself and counts down to the next try; **Retry now** tries at once,
**Stop** stops trying. **Disconnect** closes the link and does not reconnect.

The console and DM7 Link each keep their own state: nothing on the desk is changed by
connecting.

---

## 4. Show files

A show file (`.dm7show`) holds a whole show: the features in use, the Waves tables and settings,
the timecode cue list and frame rate, every macro, and the desk the show was built on. Open
another show file and everything switches to it at once.

| Button | |
|---|---|
| **Save** | Into the show file it came from (⌘S / Ctrl+S). An untitled show asks for a name. |
| **Save as…** | Into a new show file (⇧⌘S / Ctrl+Shift+S). |
| **Open…** | Another show file (⌘O / Ctrl+O). Unsaved changes are asked about first. |
| **New** | An empty show (⌘N / Ctrl+N). The console connected now becomes its desk. |

**Recent shows** opens a show file used before; **×** takes it off the list. The rail shows the
show's name, and *not saved* while it has changes. Every change is still kept in the settings
folder as it is made, so quitting loses nothing; **Save** is what puts it in the show file.

Not in a show file, because they belong to the computer: the console address, SuperRack's
adapter, the ProLink port, SuperRack's session folder. The audio interface the LTC comes in on is
in the show file and is used when this computer has an interface by that name.

### 4.1 The desk in a show file

Saved while connected, a show file keeps the console's scene list, its channel names and a copy of
every setting on it. **Desk**, on the Show page, says which console it is, when it was read and
how many scenes and named channels it holds.

### 4.2 Working offline

**Work offline** (on the startup screen, under the connection status, or on the Show page) puts the show file's desk in place of the console:
the scene list, the channel names and every parameter are there, so cues can be pointed at scenes
and macros built with no console on the table. Nothing is sent anywhere. **Go online** (or
**Connect**) goes back to the console.

A show that has never been connected to a console works offline on a blank DM7: every parameter,
no scenes. Scene cues can still be typed by number.

Offline stays on across a restart.

### 4.3 When the desk has changed

A cue, a macro and the Waves scene table name a scene by its number, and the Waves channel table
names a channel by its number. Scenes are renumbered, renamed and deleted on the desk, and channels
renamed. So at startup, after opening a show, at every connect and whenever the desk's scene list
changes, DM7 Link compares the console with the desk the show was built on. If something the show
uses has changed, a window lists it:

| | | Choices |
|---|---|---|
| **Moved** | The scene's title (or the channel's name) is now on another number. | **Use** the new number (default) · **Keep** the old one · **Remove the reference** |
| **Renamed** | The number is still there, with another title. | **Keep** (default) · **Remove the reference** |
| **Missing** | Nothing on the desk has that number or that title. | **Keep** (default) · **Remove the reference** |

**Apply** changes the show and takes the console as the show's desk. A cue whose scene is removed
is disarmed. **Later** changes nothing, and the window comes back at the next connect.

Channels are compared only while **Follow SuperRack's patch** is off: with it on, the channel
table follows the patch by itself.

---

## 5. Waves SuperRack

DM7 Link *is* the console that SuperRack's ProLink remote talks to. SuperRack connects to
DM7 Link; no other bridge software is involved.

### 5.1 First setup

**In DM7 Link — Waves ▸ Setup ▸ Waves link**

1. Choose the **Adapter**: the network SuperRack is on.
2. DM7 Link shows the two things to type into SuperRack:
   - **Console IP in SuperRack**: this computer's address on that adapter (**Copy** puts it on the
     clipboard).
   - **Port in SuperRack**: the adapter as SuperRack lists it in its Port menu (on a Mac,
     for example `00:11:22:33:44:55 - en7 -`).

**In SuperRack — Setup ▸ Controllers ▸ + ▸ ProLink LAWO Console Remote**

1. **Port**: a **wired** adapter with link. Wi-Fi is refused by SuperRack.
2. **Console IP**: the address DM7 Link shows. Port number **50002**.
3. Tick **Assign**.

The Waves page then reads **SuperRack connected**.

- Start DM7 Link **before** pressing Assign. SuperRack dials once per Assign; if DM7 Link was
  not running, untick and tick Assign again.
- SuperRack on the same Mac as DM7 Link: `127.0.0.1` works as the Console IP as well.
- On Windows, allow DM7 Link through the firewall when asked (TCP 50002).
- An adapter plugged in after SuperRack started appears in its Port menu only after SuperRack
  restarts.

### 5.2 What feeds SuperRack: PY card or Dante

**Waves ▸ Setup ▸ SuperRack is fed by**

| | |
|---|---|
| **PY card** | The Waves card in the desk's slot. PY *k* is SuperRack input *k*. If the card's channels start further up in SuperRack, set **PY 1 arrives on SuperRack input**. |
| **Dante** | SuperRack is fed from the desk's own Dante outputs (through a Dante–SoundGrid bridge). Set the **first desk Dante output to SuperRack** and the **SuperRack input it arrives on**. Up to 128 Dante ports from there are read. |

DM7 Link reads the desk's patch to know which channel feeds which SuperRack input. A channel
reaches SuperRack in one of three ways:

- its **insert** is sent out on the card (and usually returns on it),
- it is **patched straight** to a card output (a mix, a matrix, the stereo bus, a direct out tap),
- its **input** is patched from the card (an FX return coming back from SuperRack).

### 5.3 Channels tab

Every desk channel that reaches SuperRack, in card-port order, and the rack its SEL opens.

| Column | |
|---|---|
| Channel | As the desk prints it: `CH 9`, `CH 9/10` for a stereo pair, `MX 3`, `ST 1` |
| Name | The desk's channel name |
| Port | The card port: `PY 3`, `Dante 35`; `ret` = insert return, `in` = input patch |
| Rack | The SuperRack rack. Click to choose another, or **No rack** |
| Status | Where the mapping came from, or what is wrong with it (red) |

- **Follow SuperRack's patch** (on by default) fills the table from SuperRack's own input patch:
  the rack on SuperRack input *k* is the rack for the channel on port *k*. A row set by hand keeps
  its rack.
- **Name racks after channels** renames every rack the card feeds after its desk channel, now.
  With *Name racks after desk channels* on (Setup), this also happens by itself whenever a
  channel is newly patched to the card or renamed.
- **Double-click** a row to open its rack in SuperRack.
- Racks are stored **by name**, so reordering racks in SuperRack does not break the table.
- A channel that does not reach SuperRack opens nothing.

### 5.4 Scenes tab

What a DM7 scene recall does in SuperRack.

**Scene recall**:

| | |
|---|---|
| **Off** | Nothing happens in SuperRack |
| **Same number** | Scene *n* recalls the *n*-th snapshot in SuperRack's list |
| **From table** | Each scene recalls the snapshot chosen in its row |

Choose **Bank A** or **Bank B** to see that bank's scenes.

- Click a scene's **SuperRack snapshot** to choose one. Several scenes may share a snapshot.
- Click rows to pick several scenes, then:
  - **Assign a snapshot** to all of them,
  - **New snapshots**: one new SuperRack snapshot per scene, named after it, and mapped,
  - **Exclude** / **Include**: an excluded scene never recalls, stores or creates a snapshot.
- **Match by name** maps each scene to the snapshot with the same name.
- **Test** recalls the row's snapshot now, without touching the desk.
- The scene the desk is on is marked at the left edge. A red snapshot no longer exists in SuperRack.

**Storing a scene** on the desk stores its snapshot in SuperRack (Setup ▸ *Scene store stores its
snapshot*). A scene with no snapshot gets a new one named after the scene, if *A scene with no
snapshot gets a new one* is on.

### 5.5 SuperRack tab

SuperRack's own racks and snapshots, controlled from DM7 Link.

| | |
|---|---|
| **Rack** Previous / Next | Steps through racks in SuperRack |
| **Plug-in** Previous / Next | Steps through the plug-ins of the open rack |
| **View** | Normal, Rack or Overview |
| **Tempo** | SuperRack's tempo; − / + nudges it, **Tap** taps it |
| **Racks** | **Open** shows the rack in SuperRack. Double-click a name to rename it |
| **Snapshots** | Click one, then **Recall**, **Store** (overwrite with SuperRack's current state) or **Delete**. **Add** creates a new snapshot with the typed name. **Previous / Next** step through snapshots |
| **Activity** | Everything sent to SuperRack, newest first |

### 5.6 Setup tab

| Setting | |
|---|---|
| **SEL on the desk opens the rack** | Pressing SEL on either bay opens that channel's rack in SuperRack |
| **SEL again steps to the next plug-in** | Pressing SEL on the channel already selected steps to the rack's next plug-in |
| **Switch SuperRack to the rack page** | After opening a rack, show it in SuperRack's rack view |
| **A channel with no rack shows the overview** | Otherwise SuperRack stays where it is |
| **Name racks after desk channels** | Rename a rack when its channel is patched to the card or renamed |
| **Scene recall recalls a snapshot** | Uses the mapping on the Scenes tab |
| **Scene store stores its snapshot** | ...and **A scene with no snapshot gets a new one** |
| **Desk tempo sets SuperRack's tempo** | From the chosen **Source**: Tempo 1–4 or MIDI clock |

A stereo pair is selected by its left channel; its rack is mapped on that row.

### Show mode

**Show mode** (top bar, or Setup) lets only **scene recalls, SEL and tempo** reach SuperRack.
Storing snapshots, creating or deleting them and renaming racks are blocked. Show mode stays on
across a restart.

---

## 6. Timecode

### 6.1 The input

LTC arrives as an audio signal. Plug it into any line input of any audio interface. Level and
polarity do not matter.

**Timecode** page, top:

| | |
|---|---|
| **Input** | The audio interface. *System default* uses the computer's default input |
| **Channel** | The input the LTC cable is in |
| **Frame rate** | **Auto** detects 24, 25 or 30; 29.97 drop-frame is read from the signal. Fix it if the source is known |

The readout shows the incoming timecode and its state:

| State | Meaning |
|---|---|
| **Locked · 25 fps** | Timecode is running. *reverse* when it runs backwards |
| **Parked** | The same frame is arriving: the machine is stopped on it |
| **Freewheel** | The signal dropped out; the time keeps running for up to one second |
| **Reading** | A signal is arriving but is not yet decodable |
| **No signal** | The input is open and silent |
| Red text | The input will not open: the reason is shown |

macOS asks for microphone access the first time the input opens. Allow it, or timecode will
never arrive.

### 6.2 Cues

A cue is a point in the timecode and what happens there: **recall a scene** or, with Macros on,
**run a macro**. A scene can be:

- *the next scene* or *the previous scene* (the next one that exists on the desk),
- **Scene number…**: type any scene, e.g. `12` or `12.01` for a sub-scene. This works without a
  console connected; once one is, a number the desk does not have shows in red,
- a scene picked from the console's list (with its title).

| | |
|---|---|
| **Add cue** | Adds a cue at the incoming timecode, or at 00:00:00:00 with none arriving |
| **Armed** | Only armed cues fire. **Arm all** / **Disarm all** for the whole list |
| **Time** | Click to type a time. Hover the row for **−1 / +1** (one frame) and **Take** (the incoming timecode) |
| **Name** | Free text |
| **Recalls / Does** | The scene or macro. A red entry is missing on the desk or would not run |
| **Song** | Groups cues. **New song…** creates one |
| **Run** | Fires the cue now, for rehearsal. Does not change whether it is armed |
| **✕** | Deletes the cue |

**When a cue fires:** an armed cue fires when the timecode **plays through** it. A machine that
*locates* past cues (jumps from the top of the show to an hour in) fires none of them. Each cue
fires once per pass.

A cue that just fired is highlighted for a few seconds.

### 6.3 Songs

Cues in a song are listed under the song's heading: first and last time, number of cues and how
many are armed. Click a heading to open or close it. The song the timecode is in opens by itself.

### 6.4 Timeline

One lane per hour that has cues, each showing the first part of that hour; **Lane** sets how
much (30 seconds to 1 hour; *Auto* fits the cues). Amber marks are armed cues, white marks
disarmed, red marks missing scenes. The white line is the incoming timecode. Hover a mark for its
cue.

### 6.5 Live update

For re-timing a show against the real playback. Switch **Live update** on, play the show, and
press **Move Q*n* here** when the moment for the nearest cue arrives: that cue takes the incoming
time. **Undo** puts the last move back.

---

## 7. Macros

A macro is a short program of **blocks**, read top to bottom. Every block reads as a sentence
in the desk's own terms, for example:

```
When  Input channel 45 ▸ Fader ▸ Level  is greater than  -10.00 dB
    SET   Mix 3 ▸ Fader ▸ Level  to  -5.00 dB
    WAIT  2 s
    FADE  Mix 3 ▸ Fader ▸ Level  to  -∞  over  3 s
```

Values are written in each parameter's own unit (dB, Hz, ms, %, on/off). A value meant for a
fader is read as dB; the same number meant for a filter is read as Hz.

### 7.1 Blocks

| Block | What it does |
|---|---|
| **SET** | Write a value to a parameter |
| **CHANGE BY** | Move a parameter up or down by an amount, in its own unit |
| **FADE** | Move a parameter to a value over a set time |
| **SCENE** | Recall, store or update a desk scene (a number, *next* or *previous*) |
| **ASSIGN** | Keep a value in a variable, with its unit |
| **COMPUTE** | Add, subtract, multiply or divide two values into a variable. Units are checked |
| **IF** | Run the blocks inside only when a condition holds (with an *else*) |
| **WHILE** | Repeat the blocks inside while a condition holds |
| **FOR** | Count a variable from one value to another; the count can choose the channel |
| **WAIT** | Pause |
| **NOTIFY** | Show a message and write it to the record |
| **STOP** | End the run here |

A **condition** compares two values: equals, not equal, greater than, less than, greater or
equal, less or equal. A value can be a parameter, a meter level, a variable, a number with a
unit, or the incoming timecode.

A processor parameter (a plug-in's knob) is remembered with the processor it belongs to. If
the slot later holds a different processor, the macro follows the parameter by name, or stops
and says so. It never moves the wrong control.

### 7.2 Triggers: what starts a macro

A macro with no trigger is run by hand. Otherwise it starts on its own while it is **armed**:

| Trigger | Fires |
|---|---|
| **Parameter condition** | When a condition *becomes* true, and not again until it has cleared |
| **Parameter change** | Whenever the console reports a new value for a parameter |
| **Interval timer** | Every set interval |
| **Time of day** | Once a day, when the computer's clock passes a set time |
| **Timecode** | When the incoming timecode plays through a point (the same rule as cues) |
| **Scene recall** | When the console finishes recalling a scene: any scene, or one chosen |

A macro does not re-trigger itself on its own changes: after a run, its triggers re-read the desk
before they may fire again.

### 7.3 The Macros page

Two tabs: **Macros** (the list and the editor) and **Record** (what happened, the variables and
the limits). The header shows how many macros are armed or running, and holds
**Import from file**, **Export all** and **New macro**; **Stop all** appears there while a macro
runs.

**The list (left)**

Macros are grouped in folders; click a folder heading to open or close it. Each macro shows:

- an **armed** switch,
- what starts it, in words (or *Manual — no trigger*),
- how many slots are still to fill,
- a lamp while it is running, and **Run** when you hover it.

Click a macro to open it in the editor.

**The editor (right)**

| | |
|---|---|
| Name and folder | Type the name; choose a folder or **New folder…** |
| **Armed** | Arms or disarms the macro |
| **Run** / **Stop** | Starts the macro now, or stops it |
| **Export** / **Delete** | Saves this macro to a file; deletes it (asks first) |
| **Starts when** | The triggers. **Add a trigger** adds one; **✕** removes it |
| **Blocks** | The program, top to bottom. **Add a block** inserts at the white line under the selected block. **Up**, **Down** and **Remove** act on the selected block |

Keyboard: **Delete** removes the selected block; **Ctrl+Up / Ctrl+Down** (⌘ on a Mac) moves it.

**Filling a block.** Every block reads as a sentence; the boxed parts are **chips**. Click a chip
to fill it:

- a **parameter** opens the parameter picker,
- a **value** opens the value sheet: a number with its unit (and −∞ for levels), a time, a
  timecode (**Take** copies the incoming one), a text, or on/off. From the value sheet a slot
  can also take a **parameter**, a **meter** or the **timecode** instead of a fixed value,
- a choice (up / down, a curve, a scene key) opens a short list or flips at once.

An empty chip has a dashed outline; a macro with empty chips cannot be armed.

**The parameter picker.** Search for a parameter by name, or browse by area. A path such as
*Input channel ▸ Fader ▸ Level* is built one step at a time. Where a step has many elements
(channels, mixes, bands), choose:

| | |
|---|---|
| **Single** | One element, e.g. Input channel 5 |
| **Multiple** | Several at once, e.g. Mix 1–8: the block acts on each |
| **Variable** | The element a variable holds, e.g. the count of a FOR loop |

Only parameters the block can use are offered: a level can be faded, a filter type cannot.

**The meter picker** chooses a level to compare against: a channel's meter at a metering point
(**Single / Multiple / Variable** as above), or a premium-rack plug-in's meter.

### 7.4 Arming and running

- **Armed** lets a macro's triggers start it. A macro is checked when it is armed. One that
  could not run (an empty slot, a missing scene, a unit that does not fit) stays disarmed, and
  the problems are listed above the blocks. Click a problem to go to its block.
- **Run** starts a macro now, by hand, armed or not.
- **Stop** ends a running macro; **Stop all** ends every one.

Every run has fixed limits, so a mistake cannot take over the desk:

| Limit | |
|---|---|
| Changes sent to the console | 400 per run (at most 200 a second) |
| Run time | 60 s, WAIT included |
| Single WAIT | 30 s |
| Single FADE | 30 s |
| Loop turns | 2,000 per loop |
| Blocks executed | 20,000 per run |

A run that reaches a limit stops and says which one.

### 7.5 Record, variables and files

- **Record** lists what every run did and why it stopped, newest at the bottom. The tab shows
  how many errors are unread.
- **Variables** (on the Record tab) hold values between blocks and between runs, each with its
  unit. They can be added and deleted there.
- **Export all** / **Export** write macros to a file; **Import from file** reads them back, to
  move macros between computers.

Macros can also be fired from the timecode cue list ([6.2](#62-cues)).

### 7.6 Limits of the editor

- A block cannot be dragged into or out of an IF, WHILE or FOR. Remove it and add it again at
  the white line inside the branch, or move it with **Up / Down**.
- A patch source (for example *Dante 10*) is typed as text; it is checked against the desk.

---

## 8. Settings

**Features**: switch each part on or off.

| Feature off | What stops |
|---|---|
| **Waves SuperRack** | The SuperRack link closes. SuperRack shows the console as disconnected |
| **Timecode** | The audio input closes. No cue fires, neither scene nor macro |
| **Macros** | Every running macro stops and no trigger is watched. Macro cues do nothing |

A feature that is off is hidden from the rail and the show bar. Switched back on, macro triggers
start from the desk's current state, so nothing fires for what changed while they were off.

**Settings folder** opens the folder with all of DM7 Link's files.

---

## 9. Files and backups

| System | Folder |
|---|---|
| macOS | `~/Library/Application Support/DM7 Link/` |
| Windows | `%APPDATA%\DM7 Link\` |
| Linux | `~/.config/dm7-link/` |

| File | Holds |
|---|---|
| `config.json` | Settings: console address, features, adapter, Waves and timecode settings |
| `racks.json` | The channel → rack and scene → snapshot tables |
| `cues.json` | The cue list and songs |
| `macros.json` | The macros and their variables |
| `desk.json`, `desk-image.zip` | The show's desk: scene list, channel names, settings |
| `rack-logs/` | One log per day of everything sent to SuperRack |

`desk.json` and `desk-image.zip` hold the desk the show was built on. A show file is the way to
keep a show or move it to another computer; copying the folder works as well. Files are written safely:
a power cut cannot leave a half-written file.

---

## 10. Troubleshooting

| Symptom | Check |
|---|---|
| **No console found** | The computer must be on the console's network. Type the address under *Console address* |
| **SuperRack: "Failed to connect"** | DM7 Link running and **Waves** on in Settings. In SuperRack, **Port** must be the wired adapter shown as *Port in SuperRack*, **Console IP** the address DM7 Link shows. Then untick and tick **Assign** |
| SuperRack connected, SEL does nothing | The channel must reach SuperRack (Channels tab) and have a rack. *SEL on the desk opens the rack* must be on |
| Scene recall does not change the snapshot | Scenes tab: *Scene recall* not Off; the scene has a snapshot and is not excluded |
| Wrong racks named | Check *SuperRack is fed by* and the first-input offset |
| Timecode: **No signal** | Right interface and channel. Is the source playing? |
| Timecode: the input will not open | Another program may hold the interface. On macOS, allow microphone access |
| A cue did not fire | It must be armed, and the timecode must play through it, not jump past it |
| A macro will not arm | The macro shows what is wrong: an empty slot, a missing scene, a unit that does not fit |

The daily log in `rack-logs/` shows everything that happened with SuperRack.

---

## 11. What DM7 Link does not do

- **Build racks** in SuperRack from the desk's patch.
- **Snapshot scope and recall safe**: SuperRack can only change these by reloading its session,
  which interrupts audio.
- **Touch & Turn** (a desk fader driving a SuperRack plug-in control).

---

DM7 Link is not made by, endorsed by or affiliated with Yamaha or Waves. DM7 is a trademark of
Yamaha Corporation; SuperRack and SoundGrid are trademarks of Waves Audio Ltd.
