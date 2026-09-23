# __PROJECT_NAME__

A LaTeX document, compiled inside Docker -- no local LaTeX install required.

## Build it

```bash
make build          # compiles __MAIN__ to a PDF
make watch          # recompiles automatically on every save
make shell           # open a shell inside the LaTeX container
make help            # see all available commands
```

The first build pulls the `texlive/texlive` Docker image (a few GB,
one-time). Every build after that is fast.

Generated with [create-latex-app](https://github.com/mralinp/latex-academic-template).
