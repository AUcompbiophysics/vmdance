# Sphinx configuration for the VMDance documentation.
import datetime
import importlib.util

project = "VMDance"
author = "Diego Gomes"
copyright = f"{datetime.date.today().year}, {author}"
version = "1.0a1"
release = "1.0 alpha 1"

extensions = ["sphinx.ext.mathjax"]
# copy buttons on the code blocks, when sphinx-copybutton is installed (the
# pages build the same without it)
if importlib.util.find_spec("sphinx_copybutton") is not None:
    extensions.insert(0, "sphinx_copybutton")
exclude_patterns = ["_build", "Thumbs.db", ".DS_Store", "tools", "diagrams"]
highlight_language = "tcl"
# (MDANCE's documentation's)
pygments_style = "tango"
suppress_warnings = ["misc.highlighting_failure"]

html_theme = "furo" if importlib.util.find_spec("furo") is not None else "alabaster"
html_title = "VMDance"
html_static_path = ["_static"]
# MDANCE's documentation's fonts (Poppins, JetBrains Mono; the system's
# without a network); custom.css last, so that it overrides the theme
html_css_files = [
    "https://fonts.googleapis.com/css2?family=Poppins:wght@400;500;600"
    "&family=JetBrains+Mono:wght@400;500&display=swap",
    "custom.css",
]
# a link to another project's website (MDANCE's documentation) asks before
# it leaves these pages
html_js_files = ["leaving.js"]
html_favicon = "_static/logo/vmdance_mark_64.png"
GITHUB = "https://github.com/AUcompbiophysics/vmdance"
GITHUB_ICON = (
    '<svg stroke="currentColor" fill="currentColor" stroke-width="0" viewBox="0 0 16 16">'
    '<path fill-rule="evenodd" d="M8 0C3.58 0 0 3.58 0 8c0 3.54 2.29 6.53 5.47 7.59.4.07.55-.17.55-.38 '
    '0-.19-.01-.82-.01-1.49-2.01.37-2.53-.49-2.69-.94-.09-.23-.48-.94-.82-1.13-.28-.15-.68-.52-.01-.53.63-.01 '
    '1.08.58 1.23.82.72 1.21 1.87.87 2.33.66.07-.52.28-.87.51-1.07-1.78-.2-3.64-.89-3.64-3.95 0-.87.31-1.59.82-2.15'
    '-.08-.2-.36-1.02.08-2.12 0 0 .67-.21 2.2.82.64-.18 1.32-.27 2-.27.68 0 1.36.09 2 .27 1.53-1.04 2.2-.82 2.2-.82'
    '.44 1.1.16 1.92.08 2.12.51.56.82 1.27.82 2.15 0 3.07-1.87 3.75-3.65 3.95.29.25.54.73.54 1.48 0 1.07-.01 1.93-.01 '
    '2.2 0 .21.15.46.55.38A8.013 8.013 0 0016 8c0-4.42-3.58-8-8-8z"></path></svg>')
if html_theme == "furo":
    html_theme_options = {
        "light_logo": "logo/vmdance.svg",
        "dark_logo": "logo/vmdance_dark.svg",
        "sidebar_hide_name": True,
        "navigation_with_keys": True,
        # the colours and fonts of MDANCE's documentation (its conf.py)
        "light_css_variables": {
            "font-stack": '"Poppins", system-ui, -apple-system, "Segoe UI", sans-serif',
            "font-stack--monospace": '"JetBrains Mono", ui-monospace, SFMono-Regular, Menlo, monospace',
            "color-brand-primary": "#CA2D7B",
            "color-brand-content": "#0F7A90",
            "color-foreground-primary": "#0B1026",
            "color-foreground-secondary": "#454D6B",
            "color-foreground-muted": "#5F6788",
            "color-background-primary": "#FFFFFF",
            "color-background-secondary": "#F5F6FA",
            "color-background-hover": "#ECEEF5",
            "color-background-border": "rgba(11, 16, 38, 0.10)",
            "color-sidebar-link-text": "#0B1026",
            "color-sidebar-link-text--top-level": "#0B1026",
        },
        "dark_css_variables": {
            "color-brand-primary": "#EC3F96",
            "color-brand-content": "#44E1F9",
            "color-foreground-primary": "#F3F4FB",
            "color-foreground-secondary": "#A9AED6",
            "color-foreground-muted": "#858BB8",
            "color-background-primary": "#0B1026",
            "color-background-secondary": "#0E1430",
            "color-background-hover": "#1E2650",
            "color-background-border": "rgba(255, 255, 255, 0.08)",
            "color-code-background": "#131A3A",
            "color-sidebar-link-text": "#F3F4FB",
            "color-sidebar-link-text--top-level": "#F3F4FB",
        },
        "source_repository": GITHUB + "/",
        "source_branch": "main",
        "source_directory": "docs/",
        "footer_icons": [{"name": "GitHub", "url": GITHUB, "html": GITHUB_ICON, "class": ""}],
    }
else:
    html_logo = "_static/logo/vmdance.svg"
copybutton_prompt_text = r"^\$ |^% |^vmd > "
copybutton_prompt_is_regexp = True
