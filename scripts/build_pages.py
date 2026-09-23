#!/usr/bin/env python3
"""Generate the static GitHub Pages gallery listing every template.

Scans templates/*/config.mk for metadata, builds any missing PDF via
`make build`, renders a page-1 thumbnail with pdftoppm (host binary if
available, otherwise the same Docker container used to build -- no local
LaTeX/poppler install is required either way), and writes a self-contained
site/index.html plus copies of the PDFs and thumbnails into site/.
"""
from __future__ import annotations

import re
import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TEMPLATES_DIR = ROOT / "templates"
SITE_DIR = ROOT / "site"
REPO_URL = "https://github.com/mralinp/latex-academic-template"


def read_config(config_path: Path) -> dict:
    values = {"NAME": "", "DESCRIPTION": "", "TAGS": ""}
    if config_path.exists():
        for line in config_path.read_text().splitlines():
            m = re.match(r"^\s*([A-Z_]+)\s*:?=\s*(.*)$", line)
            if m and m.group(1) in values:
                values[m.group(1)] = m.group(2).strip()
    return values


def run(cmd, **kwargs):
    print("+", " ".join(cmd))
    subprocess.run(cmd, check=True, **kwargs)


def build_template(name: str) -> None:
    run(["make", "build", f"TEMPLATE={name}"], cwd=ROOT)


def render_preview(template_dir: Path, name: str) -> Path | None:
    """Render page 1 of main.pdf to a PNG. Best-effort: returns None on failure."""
    rel_dir = template_dir.relative_to(ROOT).as_posix()
    if shutil.which("pdftoppm"):
        subprocess.run(
            ["pdftoppm", "-png", "-r", "100", "-f", "1", "-l", "1", "main.pdf", "preview"],
            cwd=template_dir,
        )
    else:
        subprocess.run(
            [
                "docker", "compose", "run", "--rm", "-w", f"/work/{rel_dir}", "latex",
                "sh", "-c",
                "command -v pdftoppm >/dev/null 2>&1 && pdftoppm -png -r 100 -f 1 -l 1 main.pdf preview || true",
            ],
            cwd=ROOT,
        )
    produced = template_dir / "preview-1.png"
    return produced if produced.exists() else None


CARD_HTML = """    <article class="card">
      <div class="thumb">{thumb}</div>
      <div class="card-body">
        <h2>{title}</h2>
        <p>{description}</p>
        <div class="tags">{tags}</div>
        <div class="actions">{actions}</div>
      </div>
    </article>
"""

PAGE_HTML = """<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>LaTeX Academic Template</title>
<meta name="description" content="Dockerized LaTeX templates -- resume, IEEE, Springer, and more. No local LaTeX install required.">
<style>
  :root {{
    --bg: #f7f7f8; --fg: #1a1a1a; --muted: #5b5b63; --card: #ffffff;
    --border: #e3e3e6; --accent: #2f6fed; --tag-bg: #eef2ff;
  }}
  @media (prefers-color-scheme: dark) {{
    :root {{
      --bg: #121214; --fg: #f2f2f3; --muted: #a5a5ad; --card: #1b1b1e;
      --border: #2c2c30; --accent: #7aa2ff; --tag-bg: #23273a;
    }}
  }}
  * {{ box-sizing: border-box; }}
  body {{
    margin: 0; background: var(--bg); color: var(--fg);
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
  }}
  header {{ padding: 3rem 1.5rem 1.5rem; text-align: center; }}
  header h1 {{ margin: 0 0 0.5rem; font-size: 2rem; }}
  header p {{ margin: 0 auto; max-width: 40rem; color: var(--muted); }}
  .getting-started {{
    max-width: 44rem; margin: 0 auto 2.5rem; padding: 1.25rem 1.5rem;
    background: var(--card); border: 1px solid var(--border); border-radius: 0.75rem;
  }}
  .getting-started h2 {{ margin: 0 0 0.9rem; font-size: 1.1rem; text-align: center; }}
  .getting-started ol {{ margin: 0; padding-left: 1.2rem; display: flex; flex-direction: column; gap: 0.6rem; }}
  .getting-started li {{ font-size: 0.9rem; line-height: 1.5; }}
  .getting-started code {{
    background: var(--tag-bg); color: var(--fg); padding: 0.1rem 0.35rem;
    border-radius: 0.3rem; font-size: 0.85em;
  }}
  .getting-started pre {{
    background: var(--bg); border: 1px solid var(--border); border-radius: 0.5rem;
    padding: 0.6rem 0.75rem; overflow-x: auto; margin: 0.35rem 0 0;
  }}
  .getting-started pre code {{ background: none; padding: 0; font-size: 0.82rem; }}
  .getting-started .lede {{ font-size: 0.9rem; line-height: 1.5; color: var(--muted); text-align: center; margin: 0 0 0.9rem; }}
  .getting-started .lede code {{
    background: var(--tag-bg); color: var(--fg); padding: 0.1rem 0.35rem;
    border-radius: 0.3rem; font-size: 0.85em;
  }}
  .cmd-row {{ display: flex; align-items: stretch; gap: 0.5rem; margin-bottom: 0.9rem; }}
  .cmd-row pre {{
    flex: 1; margin: 0; background: var(--bg); border: 1px solid var(--border); border-radius: 0.5rem;
    padding: 0.7rem 0.85rem; display: flex; align-items: center; min-width: 0;
  }}
  .cmd-row pre code {{ background: none; padding: 0; font-size: 0.78rem; white-space: pre-wrap; word-break: break-all; }}
  .cmd-row .copy-btn {{ flex-shrink: 0; align-self: stretch; padding: 0 1rem; }}
  @media (max-width: 30rem) {{
    .cmd-row {{ flex-direction: column; }}
    .cmd-row .copy-btn {{ align-self: stretch; padding: 0.5rem 1rem; }}
  }}
  .secondary-links {{ text-align: center; font-size: 0.85rem; color: var(--muted); margin: 0; }}
  .secondary-links a {{ color: var(--accent); text-decoration: none; font-weight: 600; }}
  .secondary-links a:hover {{ text-decoration: underline; }}
  main {{
    max-width: 68rem; margin: 0 auto; padding: 1rem 1.5rem 4rem;
    display: grid; gap: 1.25rem;
    grid-template-columns: repeat(auto-fill, minmax(19rem, 1fr));
  }}
  .card {{
    background: var(--card); border: 1px solid var(--border); border-radius: 0.75rem;
    overflow: hidden; display: flex; flex-direction: column;
  }}
  .thumb {{
    aspect-ratio: 8.5 / 11; background: var(--bg); display: flex;
    align-items: center; justify-content: center; overflow: hidden;
    border-bottom: 1px solid var(--border);
  }}
  .thumb img {{ width: 100%; height: 100%; object-fit: cover; object-position: top; }}
  .thumb .placeholder {{ color: var(--muted); font-size: 0.85rem; }}
  .card-body {{ padding: 1rem 1.1rem 1.1rem; display: flex; flex-direction: column; gap: 0.5rem; flex: 1; }}
  .card-body h2 {{ margin: 0; font-size: 1.05rem; }}
  .card-body p {{ margin: 0; color: var(--muted); font-size: 0.9rem; line-height: 1.4; flex: 1; }}
  .tags {{ display: flex; flex-wrap: wrap; gap: 0.35rem; }}
  .tags span {{
    background: var(--tag-bg); color: var(--accent); font-size: 0.72rem;
    padding: 0.15rem 0.5rem; border-radius: 999px; font-weight: 600;
  }}
  .actions {{ display: flex; gap: 0.5rem; margin-top: 0.25rem; flex-wrap: wrap; }}
  .btn {{
    font-size: 0.82rem; font-weight: 600; text-decoration: none; padding: 0.4rem 0.75rem;
    border-radius: 0.5rem; border: 1px solid var(--border);
  }}
  .btn.primary {{ background: var(--accent); color: #fff; border-color: var(--accent); }}
  .btn.ghost {{ color: var(--fg); }}
  .btn:hover {{ opacity: 0.85; }}
  footer {{ text-align: center; color: var(--muted); font-size: 0.85rem; padding-bottom: 3rem; }}
  footer a {{ color: var(--accent); }}
</style>
</head>
<body>
<header>
  <h1>LaTeX Academic Template</h1>
  <p>Dockerized LaTeX templates you can compile with one command -- no local LaTeX install required. Browse the available templates below.</p>
</header>
<section class="getting-started">
  <h2>Start a new project</h2>
  <p class="lede">One command, no cloning required -- like <code>npx create-react-app</code>, but for LaTeX. Just needs <a href="https://docs.docker.com/get-docker/">Docker</a> installed and running.</p>
  <div class="cmd-row">
    <pre id="one-liner"><code>bash -c "$(curl -fsSL https://raw.githubusercontent.com/mralinp/latex-academic-template/main/create-latex-app.sh)"</code></pre>
    <button type="button" class="btn primary copy-btn" data-target="one-liner">Copy</button>
  </div>
  <p class="lede">A short wizard then asks you to <strong>pick a template</strong>, <strong>import a local .zip</strong> (e.g. from Overleaf), or <strong>import a git URL</strong> -- and hands you a ready-to-build project with its own git repo.</p>
  <p class="secondary-links">
    Want the whole gallery repo instead?
    <a href="{repo}/generate">Use this template</a> ·
    <a href="{repo}/fork">Fork</a> ·
    <a href="{repo}">View source</a>
  </p>
</section>
<script>
document.querySelectorAll(".copy-btn").forEach(function (btn) {{
  btn.addEventListener("click", function () {{
    var text = document.getElementById(btn.dataset.target).innerText;
    navigator.clipboard.writeText(text).then(function () {{
      var original = btn.textContent;
      btn.textContent = "Copied!";
      setTimeout(function () {{ btn.textContent = original; }}, 1500);
    }});
  }});
}});
</script>
<main>
{cards}
</main>
<footer>
  <p>Built with <a href="{repo}">latex-academic-template</a>, compiled inside the official <a href="https://hub.docker.com/r/texlive/texlive">texlive/texlive</a> Docker image.</p>
</footer>
</body>
</html>
"""


def main() -> None:
    if SITE_DIR.exists():
        shutil.rmtree(SITE_DIR)
    (SITE_DIR / "previews").mkdir(parents=True)
    (SITE_DIR / "pdfs").mkdir(parents=True)

    cards = []
    for template_dir in sorted(p for p in TEMPLATES_DIR.iterdir() if p.is_dir()):
        main_tex = template_dir / "main.tex"
        if not main_tex.exists():
            continue
        name = template_dir.name
        cfg = read_config(template_dir / "config.mk")
        title = cfg["NAME"] or name
        description = cfg["DESCRIPTION"] or "No description provided."
        tags = cfg["TAGS"].split()

        pdf_path = template_dir / "main.pdf"
        if not pdf_path.exists():
            build_template(name)

        thumb_html = '<span class="placeholder">Preview unavailable</span>'
        actions = [
            f'<a class="btn ghost" href="{REPO_URL}/tree/main/templates/{name}">View source</a>'
        ]

        if pdf_path.exists():
            shutil.copy(pdf_path, SITE_DIR / "pdfs" / f"{name}.pdf")
            actions.insert(0, f'<a class="btn primary" href="pdfs/{name}.pdf">Download PDF</a>')

            preview = render_preview(template_dir, name)
            if preview:
                shutil.move(str(preview), SITE_DIR / "previews" / f"{name}.png")
                thumb_html = f'<img src="previews/{name}.png" alt="{title} preview">'
            for leftover in template_dir.glob("preview-*.png"):
                leftover.unlink()

        tag_html = "".join(f"<span>{t}</span>" for t in tags)
        cards.append(
            CARD_HTML.format(
                thumb=thumb_html,
                title=title,
                description=description,
                tags=tag_html,
                actions="".join(actions),
            )
        )

    html = PAGE_HTML.format(cards="".join(cards), repo=REPO_URL)
    (SITE_DIR / "index.html").write_text(html)
    print(f"Wrote {SITE_DIR / 'index.html'} with {len(cards)} template(s).")


if __name__ == "__main__":
    main()
