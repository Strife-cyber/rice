# Catppuccin Mocha rice — Linux Mint

Terminal → dev tools → desktop → login & boot, in one script.

```bash
bash install.sh            # everything (asks for sudo once)
bash install.sh --no-grub  # everything except the boot menu
bash install.sh desktop    # just one phase
bash install.sh --sync     # copy your current configs back into dotfiles/
bash install.sh --help
```

Fresh machine: `git clone git@github.com:Strife-cyber/rice.git ~/rice && bash ~/rice/install.sh`

The `apps` phase themes Zen, VS Code and the JetBrains IDEs, so install those first, or run `bash install.sh apps` again afterwards.

Then log out and back in. A full run takes about 20–30 minutes, most of it the one-time Eww build (the hover dashboard).

| Path | What |
|---|---|
| `install.sh` | The installer (10 phases, safe to re-run) |
| `dotfiles/` | Configs, mirrored at their `$HOME` paths; `@HOME@` is filled in on install |
| `wallpapers/` | Copied to `~/Pictures/Wallpapers` (default: `shaded_landscape.png`) |
| `backups/` | Cinnamon settings dumps taken before the panel is changed |
| `system-setup.reference.sh` | The original root-only script, kept for reference |

Undo: `dconf load /org/cinnamon/ < backups/<file>.dconf` · GRUB: `/etc/default/grub.bak-rice` · dotfiles: `~/.rice-backup/<timestamp>/`.

The full guide (every tool, shortcut and gotcha) is in the Claude doc "Catppuccin Mocha Rice — Linux Mint".
