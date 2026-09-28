# stealrobo

**Steal a Bot**: steal a ridiculous robot, survive the escape, and build a workshop
full of machines. The code lives in this repo and is synced into Roblox Studio with
[Rojo](https://rojo.space).

The current build is the **greybox prototype** from the design doc's playtest plan
(round 1). It answers one question: *is stealing and escaping fun with no
progression at all?* See [Greybox playtest](#greybox-playtest) below.

## Connect to Roblox Studio

### 1. Install the tools (one time)

1. Install [Git](https://git-scm.com/downloads) and [VS Code](https://code.visualstudio.com/).
2. In VS Code, open the Extensions tab and install **Rojo** (by evaera).
3. Install the Rojo Studio plugin. It doesn't need to come from the Creator Store.
   Use any one of these:
   - **VS Code (easiest):** press `Ctrl+Shift+P` (`Cmd+Shift+P` on Mac), run
     **Rojo: Open Menu**, and click **Install Roblox Studio plugin**.
   - **Command line:** if you have the Rojo CLI, run `rojo plugin install`.
   - **By hand:** download `Rojo.rbxm` from the
     [Rojo GitHub releases](https://github.com/rojo-rbx/rojo/releases). In Studio,
     open the **Plugins** tab, click **Plugins Folder**, and drop the file in.

   Restart Studio afterwards. Only use the official plugin from the Rojo GitHub
   or the Rojo tools above. Copies on the Creator Store from other uploaders can
   be fake or malicious.

### 2. Get the code

```sh
git clone https://github.com/lemuelreub-maker/stealrobo.git
```

Open the `stealrobo` folder in VS Code (**File → Open Folder**).

### 3. Start the Rojo server

In VS Code, press `Ctrl+Shift+P` (`Cmd+Shift+P` on Mac), run **Rojo: Open Menu**,
and click `default.project.json`. If VS Code asks to install Rojo, click yes.
The server starts on port `34872`.

(With the Rojo CLI you can run `rojo serve` in the project folder instead.)

### 4. Connect Studio

1. Open a place in Roblox Studio. A new **Baseplate** works.
2. Go to **Plugins → Rojo** and click **Connect**.
3. Press **Play**. The Output window should print
   `[StealABot] Greybox ready.`

Studio now updates live whenever a file in `src/` changes.

### 5. Getting new changes

```sh
git pull
```

With Rojo connected, the new code appears in Studio right away.

## Where the code goes

| Folder        | Shows up in Studio as                          | Runs on |
| ------------- | ---------------------------------------------- | ------- |
| `src/server`  | `ServerScriptService.Server`                   | Server  |
| `src/client`  | `StarterPlayer.StarterPlayerScripts.Client`    | Client  |
| `src/shared`  | `ReplicatedStorage.Shared`                     | Both    |

How file names become Studio objects:

- `name.server.luau` becomes a **Script**
- `name.client.luau` becomes a **LocalScript**
- `name.luau` becomes a **ModuleScript**
- `init.server.luau` / `init.client.luau` turn the folder itself into that script

## Notes

- Rojo only syncs scripts and the folders listed in `default.project.json`. Parts,
  models and maps you build in Studio stay in the place file, so save the place in
  Studio as usual.
- Edit scripts in VS Code, not in Studio. Rojo overwrites Studio edits to synced scripts.

## Greybox playtest

### What's in it

The map is built by code when you press **Play**, so you won't see it in edit
mode. It's placed away from the middle of the place (at X = 3000) so it never
overlaps anything you've built, and every player spawns in their own workshop.

- **Safe zone**: 8 workshops along a street. Nothing can be stolen here and the
  Warden can't enter.
- **Factory**: 5 layers in a straight line, each harder than the last:

  | Layer | Hazard | Robots | Warden speed |
  | --- | --- | --- | --- |
  | 1 Scrapyard | Scrap piles | Bolt Bot | 9 |
  | 2 Assembly Hall | Pillars and a sweep light (1.5 s in it = Warden surge) | Spring Bot | 11 |
  | 3 Maintenance Tunnels | Zigzag walls; yellow Spring gaps only a bounce clears | Spring Bot | 12.5 |
  | 4 Loading Yard | Side conveyors push you deeper; crate slalom | Spring Bot | 14.5 |
  | 5 Press Floor | Presses on a 4 s beat push you back 6 studs | Spring Bot | 16 |

- **Heist rules**: hold Interact to unplug (1.5–2 s), the Warden boots for
  2.5 s, then follows your exact path. If it gets within 3.5 studs, the robot goes
  back to its dock (no damage, nothing lost). It stops dead at the green safe line.
  Walk into your own workshop past the loading-bay line to secure the robot.
- **Spring Bot** bounces you 9 studs every 2.5 s; the bar on the HUD warns you.
  **Bolt Bot** rattles when you sprint, lighting you up for everyone.
- **Tag Net**: fire it inside the factory at another player who is carrying a
  robot. They drop it, get 3 s to grab it back, then anyone can take it. Netted
  players are immune for 20 s (blue outline).

### Controls

| Action | PC | Mobile | Console |
| --- | --- | --- | --- |
| Unplug / pick up | Hold E | Hold the prompt | Hold X |
| Drop | E | Drop button | X |
| Sprint | Shift (hold) | Sprint button | L3 |
| Tag Net | Left click | Net button | R2 |

### Testing with several players

In Studio, open the **Test** tab, set **Clients and Servers** to *Local Server* with
2–4 players, and click **Start**. That's the only way to try the Tag Net alone.
For real sessions, set the place's server size to 8 (one per workshop).

### Reading the results

Everything the playtest plan measures is printed to the **Output** window with a
`[Playtest]` prefix: unplugs, escapes, catches per layer, the closest the Warden got,
run times and Tag Net hits. Type `/stats` in chat for a summary, which includes:

- catch rate per layer (targets: under 5% in layer 1, about 15% in layer 3, about 40% in layer 5)
- top-quartile run time as a % of the median (target: 60% or less)
- Tag Net hit rate (target: 25–45%)

### Tuning

Every number from the design doc is in `src/shared/Config.luau` (Warden speeds, head
start, net speed and range, hazard timings). Robots are rows in
`src/shared/RobotDefs.luau`. If a layer misses its catch target, change that layer's
Warden speed rather than the head start, as the doc recommends.
