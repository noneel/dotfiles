# Overrides Directory

Customize your dotfiles without modifying upstream roles. This directory is git-ignored by upstream, keeping your fork clean for merges.

## Override Levels

| Level | Location | Use Case |
|-------|----------|----------|
| Variables | `group_vars/user.yml` | Change values without touching roles |
| Files/Vars | `roles/{role}/files/` or `vars/` | Replace config files, keep role logic |
| Full Role | `custom_roles/{role}/` | Complete role replacement |

## Quick Start

### 1. Override Variables

```yaml
# overrides/group_vars/user.yml
git_user_name: "Your Name"
git_user_email: "you@example.com"
exclude_roles:
  - role_you_dont_want
```

### 2. Override Config Files

```bash
# Replace bash configs
mkdir -p overrides/roles/bash/files
cp ~/.bashrc overrides/roles/bash/files/.bashrc
```

Roles using `override_utils` check `overrides/roles/{role}/files/` first.

### 3. Override Role Variables

```yaml
# overrides/roles/neovim/vars/main.yml
neovim_version: "0.10.0"
```

### 4. Replace Entire Role

```bash
# Create your own neovim role
mkdir -p overrides/custom_roles/neovim/tasks
# Add tasks/main.yml, files/, templates/, etc.
```

`ansible.cfg` searches `overrides/custom_roles/` before `roles/`.

## Supported Roles

These roles check for overrides via `override_utils`:

- 1password, alacritty, awesomewm, bash, borders, btop
- claude, gh, ghostty, glab, hammerspoon, k9s
- kitty, lsd, neofetch, neovim, opencode, pwsh
- starship, system, taskfile, tmux, zsh

## Workflow

1. Fork upstream repo
2. Add customizations in `overrides/`
3. Commit your overrides
4. Pull upstream changes - no conflicts with your customizations
