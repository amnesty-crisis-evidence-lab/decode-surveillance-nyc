CONVERT = jupyter nbconvert --to html
SRCS1 = $(wildcard djw*.ipynb)

all: djw_analysis.docx $(SRCS1:.ipynb=.html)

%.html: %.ipynb
	$(CONVERT) $*

djw_analysis.docx: djw_analysis.ipynb
	 pandoc djw_analysis.ipynb -s -o djw_analysis.docx


