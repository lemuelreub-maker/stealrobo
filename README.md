# stealrobo

A Roblox game whose code lives in this repo and is synced into Roblox Studio with [Rojo](https://rojo.space).

## Connect to Roblox Studio

### 1. Install the tools (one time)

1. Install [Git](https://git-scm.com/downloads) and [VS Code](https://code.visualstudio.com/).
2. In VS Code, open the Extensions tab and install **Rojo** (by evaera).
3. Install the Rojo plugin in Studio: open Roblox Studio, go to the **Plugins** tab,
   click **Manage Plugins**, find **Rojo**, and install it. You can also get it from
   the Creator Store.

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
   `Server script synced from Rojo` and `Hello from Rojo!`.

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
