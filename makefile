SERVICE := latex
MAIN := main.tex

.PHONY: all xelatex pdflatex clean clean-all shell

all: pdflatex

# XeLaTeX — for English + Persian (xepersian)
xelatex:
	docker compose run --rm $(SERVICE) \
		latexmk \
		-xelatex \
		-interaction=nonstopmode \
		-synctex=1 \
		$(MAIN)

# pdfLaTeX — for English-only documents
pdflatex:
	docker compose run --rm $(SERVICE) \
		latexmk \
		-pdf \
		-interaction=nonstopmode \
		-synctex=1 \
		$(MAIN)

clean:
	docker compose run --rm $(SERVICE) \
		latexmk \
		-c \
		$(MAIN)

clean-all:
	docker compose run --rm $(SERVICE) \
		latexmk \
		-C \
		$(MAIN)

shell:
	docker compose run --rm $(SERVICE) bash