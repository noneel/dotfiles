# Research: Customizable Dotfiles Architecture

## Problem Statement

Users must fork the entire repo to make minor customizations (e.g., different neovim settings). This creates:
- Maintenance burden keeping fork in sync with upstream
- No separation between shared config and personal preferences
- Difficult onboarding for new users who want small tweaks

## Current State

### Existing Customization Mechanisms

| Mechanism | Location | Scope |
|-----------|----------|-------|
| Role toggling | `group_vars/all.yml` | Enable/disable entire roles |
| OS-specific tasks | `roles/*/tasks/{Ubuntu,Darwin}.yml` | Per-distro installation |
| External hooks | `~/.raftrc`, `~/.bash_lumen` | Machine-local bash config |
| Private file | `~/.config/bash/.bash_private` | Secrets/local overrides |

### Limitations

1. **Neovim**: Symlinks entire `files/` directory - all-or-nothing
2. **No `host_vars/`**: No per-machine variable overrides
3. **No templates**: Config files are static, not customizable per-host
4. **No overlay pattern**: Can't extend configs without modifying source

---

## Recommended Strategies

### Strategy 1: Local Override Files (Low Effort)

Pattern used by thoughtbot dotfiles. Each config sources a `.local` file if present.

**Implementation for Neovim:**

```lua
-- In init.lua, at the end:
local local_config = vim.fn.stdpath('config') .. '/lua/local/init.lua'
if vim.fn.filereadable(local_config) == 1 then
  dofile(local_config)
end
```

**Implementation for other configs:**
- Add `source ~/.config/X/local.conf` pattern to configs
- Local files are gitignored, never committed

**Pros:**
- Minimal changes to existing structure
- Users can override anything
- No templating complexity

**Cons:**
- Users must manually create local files
- No sharing of common customization patterns
- Overrides happen at runtime, not generation time

---

### Strategy 2: Ansible host_vars/group_vars (Medium Effort)

Leverage Ansible's variable precedence for per-machine customization.

**Implementation:**

```
dotfiles/
├── group_vars/
│   └── all.yml          # Defaults
├── host_vars/
│   ├── work-laptop.yml  # Work machine overrides
│   └── personal-pc.yml  # Home machine overrides
└── roles/
    └── neovim/
        └── templates/
            └── lua/
                └── config/
                    └── options.lua.j2
```

**Example host_vars/work-laptop.yml:**
```yaml
neovim:
  colorscheme: "tokyonight"
  font_size: 14
  copilot_enabled: true

git_user_email: "work@company.com"
```

**Example template (options.lua.j2):**
```lua
vim.opt.tabstop = {{ neovim.tabstop | default(2) }}
vim.opt.colorscheme = "{{ neovim.colorscheme | default('catppuccin') }}"
```

**Pros:**
- Native Ansible pattern
- Strong precedence system
- Can share common overrides via group_vars

**Cons:**
- Requires converting files to templates
- More complex maintenance
- Breaking change for existing users

---

### Strategy 3: Layered Config Directories (Medium Effort)

Separate "base" and "personal" configs that merge at deployment.

**Implementation:**

```
dotfiles/
├── base/
│   └── neovim/
│       └── lua/
│           └── plugins/
│               └── lsp.lua
└── personal/           # Gitignored or separate repo
    └── neovim/
        └── lua/
            └── plugins/
                └── ai.lua      # Adds to base
                └── lsp.lua     # Overrides base
```

**Deployment task:**
```yaml
- name: Deploy base config
  file:
    src: "{{ role_path }}/files/base"
    dest: "~/.config/nvim"
    state: link

- name: Overlay personal config
  copy:
    src: "{{ dotfiles_personal_dir }}/neovim/"
    dest: "~/.config/nvim/"
  when: dotfiles_personal_dir is defined
```

**Pros:**
- Clear separation of concerns
- Personal config can be separate repo
- Supports both override and extend patterns

**Cons:**
- More complex directory structure
- Merge order matters
- Potential conflicts

---

### Strategy 4: chezmoi Migration (High Effort)

Replace Ansible with chezmoi for dotfiles management.

**Features gained:**
- Native templating with machine detection
- `.chezmoiignore` for machine-specific file inclusion
- Secrets management integration
- Two-way diff before applying

**Example template:**
```
{{- if eq .chezmoi.hostname "work-laptop" }}
vim.g.copilot_enabled = true
{{- else }}
vim.g.copilot_enabled = false
{{- end }}
```

**Pros:**
- Purpose-built for dotfiles
- Excellent machine-to-machine handling
- Active development, large community

**Cons:**
- Complete rewrite required
- Different mental model from Ansible
- Loses Ansible's package installation capabilities

---

### Strategy 5: Neovim-Specific - NVIM_APPNAME (Neovim Only)

Use `NVIM_APPNAME` for entirely separate configurations.

**Implementation:**
```bash
# In .bashrc or alias
alias nvim-work="NVIM_APPNAME=nvim-work nvim"
alias nvim-personal="NVIM_APPNAME=nvim-personal nvim"
```

Configs stored in:
- `~/.config/nvim/` (default)
- `~/.config/nvim-work/` (work variant)
- `~/.config/nvim-personal/` (personal variant)

**Pros:**
- Built into Neovim
- Complete isolation between configs
- Can maintain multiple configs simultaneously

**Cons:**
- Only solves Neovim
- Config duplication between variants
- Must remember which alias to use

---

### Strategy 6: Neovim Plugin - neoconf.nvim (Neovim Only)

Use [neoconf.nvim](https://github.com/folke/neoconf.nvim) for project/machine-local LSP settings.

**Supports:**
- Global `~/.config/nvim/neoconf.json`
- Project-local `.neoconf.json`
- Per-machine overrides via standard Neovim mechanism

**Pros:**
- No fork needed for LSP customization
- Works alongside existing config
- Familiar JSON format

**Cons:**
- Only handles LSP settings
- Doesn't solve broader customization needs

---

## Recommendation

### Phased Approach

**Phase 1 - Quick Wins (Strategy 1 + 2):**
1. Add local override sourcing to neovim `init.lua`
2. Create `host_vars/` directory with example
3. Document the pattern for users

**Phase 2 - Structured Customization:**
1. Identify high-customization configs (neovim, git, shell)
2. Convert key files to Jinja2 templates
3. Define variable schema in `group_vars/all.yml`

**Phase 3 - Advanced (Optional):**
1. Evaluate chezmoi for fresh installs
2. Consider separate "personal" overlay repo pattern

### Immediate Actions

1. Add to `roles/neovim/files/init.lua`:
   ```lua
   -- Local overrides (create ~/.config/nvim/lua/local/init.lua)
   pcall(require, 'local')
   ```

2. Create `host_vars/.gitkeep` with README explaining usage

3. Add `lua/local/` to neovim's `.gitignore`

4. Document in repo README

---

## Sources

- [Thoughtbot Dotfiles - Local Override Pattern](https://thoughtbot.com/upcase/videos/intro-to-dotfiles)
- [chezmoi - Machine-to-Machine Differences](https://www.chezmoi.io/user-guide/manage-machine-to-machine-differences/)
- [chezmoi - Templating](https://www.chezmoi.io/user-guide/templating/)
- [Ansible Variable Precedence](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_variables.html)
- [Ansible Inventory Guide](https://docs.ansible.com/ansible/latest/inventory_guide/intro_inventory.html)
- [neoconf.nvim - Project Local Settings](https://github.com/folke/neoconf.nvim)
- [nvim-config-local - Secure Local Config](https://github.com/klen/nvim-config-local)
- [Neovim NVIM_APPNAME](https://neovim.io/doc/user/starting.html)
- [ArchWiki Dotfiles](https://wiki.archlinux.org/title/Dotfiles)
